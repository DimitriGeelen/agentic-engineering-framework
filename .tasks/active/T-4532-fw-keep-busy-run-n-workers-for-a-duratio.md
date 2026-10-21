---
id: T-4532
name: "fw keep-busy: run N workers for a duration over a scoped backlog, refill on
  completion, and cool down to a target count"
description: >
  Inception: fw keep-busy: run N workers for a duration over a scoped backlog, refill
  on completion, and cool down to a target count

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-21T10:53:39Z
last_update: 2026-10-21T10:54:14Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-10-21T10:54:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-4532: fw keep-busy: run N workers for a duration over a scoped backlog, refill on completion, and cool down to a target count

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: What does "scope q1 q2" mean?** BVP rank quadrants (value vs cost: Q1 high value / low cost …), horizon, arc, or tags?
  confidence: 1
  disposition: deferred
  rationale: Proposal reads it as BVP quadrants and also accepts horizon:, arc:, tag: and explicit task lists; the operator confirms.
- **IW-2: Who runs the loop: the parent agent session (as on 2026-10-21) or a standalone supervisor process?**
  confidence: 1
  disposition: deferred
  rationale: The parent session costs context per completion and dies with the session (two restarts on 2026-10-21 orphaned workers and loops); a supervisor survives but cannot judge closes that need an agent. Candidate: supervisor dispatches and refills, the parent only closes and answers decisions.
- **IW-3: Which guards are mandatory?**
  confidence: 2
  disposition: deferred
  rationale: From 2026-10-21: worker cap never above the operator's TERMLINK_MAX_WORKERS; host brake on I/O and CPU pressure (T-4525 HOST_LOAD_SHARE); stop on a subscription session limit until reset; budget band (Amber small only, Red stop); one worker per converging write-set; foreground-only tests; skip tasks needing an operator decision; never force a close.

## Proposal (verbs)

```
fw keep-busy start --workers N [--for 1h|8h|1d] [--scope bvp:Q1,Q2|horizon:now|arc:<slug>|tag:<t>|tasks:T-A,T-B]
fw keep-busy status                 # target, running, finished, closed, refused, braked-by, time left
fw keep-busy set --workers N        # raise or lower the target while running
fw keep-busy cooldown [--to N]      # stop refilling until running <= N (default 0); running workers finish
fw keep-busy stop                   # cooldown --to 0 and end the run (never kills a running worker)
```

The duration ends in an automatic `cooldown --to 0`. Every dispatch, refill, brake and close goes to one run ledger.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

Operator idea 2026-10-21 after a day of manually keeping 10 TermLink workers busy. The manual loop worked (about 100 tasks closed) but needed the parent agent to notice completions, pick tasks, refill slots and brake on host load; it repeatedly ran under capacity (missed completions), lost work (workers ending while waiting for background tests, session limits, restarts) and overloaded the shared host (I/O pressure 88%). A verb makes that loop explicit, bounded and observable, and puts today's guards in one place.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-21T10:54:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
