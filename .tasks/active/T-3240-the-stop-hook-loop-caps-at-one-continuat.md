---
id: T-3240
name: "the Stop-hook loop caps at ONE continuation — stop_hook_active is checked before
  our own caps"
description: >
  MEASURED (T-3239 E2, live claude -p against the real driver): an armed run produces
  exactly one 'decision=continue reason=iteration-1' and then 'decision=stop reason=stop_hook_active=true
  (platform runaway guard)'. Brake 3a (stop-driver.sh:87-101) is checked ahead of
  every one of our own caps, and Claude Code sets stop_hook_active on any stop following
  a hook-driven continuation, so the second stop of any run always yields there. Consequence:
  expiry, max_tasks and the tier ceiling are never consulted inside a session, and
  the arc's 'multi-cycle continuous session' is two turns. The driver's own header
  states the opposite intent — 'our counter is meant to stop the loop first, leaving
  the vendor's cap as the backstop we did not write'. This is a SOVEREIGNTY decision,
  not a bug to quietly fix: honouring stop_hook_active is what keeps a bug in our
  counter from becoming an unbounded loop, and widening it needs an operator call
  plus a real in-session turn counter to bound it. Evidence: docs/reports/T-3239-continuous-loop-demo/evidence/E2-armed-*.

status: captured
workflow_type: inception
owner: human
horizon: now
tags: [arc:continuous-run, loop, sovereignty]
components: []
related_tasks: [T-3239, T-3233, T-3163]
created: 2026-09-01T07:30:33Z
last_update: '2026-09-01T07:45:17Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-09-01T07:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T07:45:17Z'
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

# T-3240: the Stop-hook loop caps at ONE continuation — stop_hook_active is checked before our own caps

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

## Candidate Answers

<!-- Agent-supplied candidates. The decision itself remains the operator's; nothing
     here modifies the Recommendation below. -->

### 2026-09-03 — Candidate C: drive from outside, not from inside (operator-proposed)

Filed as **T-3254**. An external cron reads `.continuous-mode.yaml` and **injects**
a turn into an idle registered session when the armed conditions hold.

**Why it bears on this decision.** An injected prompt is a *new user turn*, not a
hook-driven continuation, so Claude Code never sets `stop_hook_active` for it. The
cap this task was filed about is therefore **sidestepped rather than widened** —
the vendor's runaway guard stays exactly where it is, fully intact, and keeps
doing its job for the M1 path we would no longer be using.

**It dissolves half the stated blocker.** The rationale below says the question
"cannot be answered without also deciding what in-session counter would bound it."
Candidate C needs **no in-session counter at all**: cron is wall-clock
rate-limited by construction, so the runaway ceiling is a property of the
scheduler rather than of logic we have to get right. A hook loop can re-drive
itself at machine speed; this cannot inject more than once per tick. That is a
materially stronger guarantee than any counter we would have written.

**What it does NOT dissolve.** The autonomy-ceiling half is untouched, and one
thing gets sharper: going *around* the guard means **we own the bounding
entirely**. The exposure is relocated, not removed. So the operator question
narrows from *"should a session drive more than one turn, and bounded by what?"*
to *"is an externally-driven turn acceptable, given that our four bounds
(`max_iterations`, `max_tasks`, expiry, tier ceiling) are the only thing standing
behind it?"*

**Hard prerequisite.** Those four bounds do not currently bind. E10 (T-3250)
measured the tier ceiling recording a breach, freezing the counter and disarming
the state file while the session closed the over-ceiling task anyway;
`max_iterations` has the identical hole. **T-3253 must land first** — T-3254
asserts that mechanically rather than trusting anyone to remember it.

## Recommendation

**Recommendation:** DEFER

**Rationale:** Evidence gap is genuine: the measurement establishes the cap is one continuation, but whether the loop SHOULD run longer per session is an operator call about autonomy ceiling, and it cannot be answered without also deciding what in-session counter would bound it. Both halves need the operator.

<!-- 2026-09-03: the second half of this rationale ("cannot be answered without
     deciding what in-session counter would bound it") is superseded by Candidate C
     above, which requires no in-session counter. Left unedited because the
     Recommendation is the operator's to revise, not the agent's. -->

## Decisions

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
