---
id: T-3181
name: "Refine the continuous-run loop model node by node into a buildable spec (arc-012)"
description: >
  Inception: Refine the continuous-run loop model node by node into a buildable spec
  (arc-012)

status: started-work
arc_id: continuous-run
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-26T20:00:07Z
last_update: 2026-08-26T20:01:12Z
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
  - ts: '2026-08-26T20:01:12Z'
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

# T-3181: Refine the continuous-run loop model node by node into a buildable spec (arc-012)

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

- **IW-1: Which caps may end a run, and what does the "run cap" count — turns, tasks, or sessions?**
  Four caps now exist in `.context/working/.continuous-mode.yaml` (`max_iterations`,
  `max_tasks`, `tier_ceiling`, `expires_after_seconds`). The operator's stated terminal
  conditions are arc-drained or run-cap, and wall-clock is explicitly NOT one of them —
  yet `expires_after_seconds` is the last thing that actually terminated a run.
  confidence: 1
  disposition:
  rationale:

- **IW-2: Does the halt mechanism satisfy the sovereignty requirement now that it is built?**
  v5 filed this MISSING. `stop-driver.sh:60,80-82` reads a halt file as Brake 1, before
  anything else votes. Open: is a file enough without a Watchtower control, and is it
  reachable when the model is the thing misbehaving?
  confidence: 2
  disposition:
  rationale:

- **IW-3: Is a deliberately-RED conformance rail entry a legitimate use of the rail?**
  Registering the `SessionStart source?` gateway as a vocabulary-set entry would go red on
  landing (the `clear` branch is not in `post-compact-resume.sh`'s allowlist) and stay red
  until the allowlist widens — converting prose into a self-reporting audit finding.
  confidence: 1
  disposition:
  rationale:

- **IW-4: Is our PreCompact handover already compaction-grade, and how would we know?**
  Nobody has taken `LATEST.md` into a genuinely cold session and measured whether it
  resumes. Cheap to falsify; nothing should be built on top of it before it is.
  confidence: 0
  disposition:
  rationale:

- **IW-5: On hitting a human gate mid-run, does the run park the task and take the next, or stop and notify?**
  (v5's Q5.) With ~48 started-work tasks, most human-owned, an arc drain hits one almost
  immediately. Park-and-next keeps the run alive but grows a pile nobody asked for;
  stop-and-notify is honest but may end the run in its first minutes.
  confidence: 1
  disposition:
  rationale:

- **IW-6: Why did the claude-fw wrapper leave its restart loop instead of iterating?**
  Measured tonight: restart branch ran at 21:25:46 (sentinel written), but the wrapper
  running now is a different PID started by hand at 21:39:52. Links 1-4 fired; link 5
  did not. Not in v5 — v5 records the supervisor as live with only a flag defect.
  confidence: 1
  disposition:
  rationale:

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

**Recommendation:** DEFER

**Rationale:**

Filed at the start of the walkthrough — the operator and I are about to go through draft-continuous-run-loop v5 node by node. The four open questions (IW-2 halt authority, IW-3 deliberately-red rail entry, IW-4 is PreCompact compaction-grade, Q5 park-vs-notify on a human gate) are genuine evidence gaps, not confidence gaps: none has been walked yet. This DEFER is expected to resolve to GO or NO-GO per node as the dialogue produces evidence.

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

### 2026-08-26T20:01:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
