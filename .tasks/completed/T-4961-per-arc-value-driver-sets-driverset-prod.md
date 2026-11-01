---
id: T-4961
name: "Per-arc value-driver sets (driver_set: product) — 010-termlink T-3638 ask"
description: >
  Inception: Per-arc value-driver sets (driver_set: product) — 010-termlink T-3638
  ask

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-11-01T12:39:56Z
last_update: 2026-11-01T14:47:59Z
date_finished: 2026-11-01T14:47:59Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-11-01T12:45:14Z'
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
cost_estimate_proposed:
  - ts: '2026-11-01T12:45:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=120,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4961: Per-arc value-driver sets (driver_set: product) — 010-termlink T-3638 ask

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

- **IW-1: Should an arc (and a task through its arc) be able to name its own value-driver set?**
  confidence: 3
  disposition: answered
  rationale: operator chose "GO, narrow" in chat 2026-11-01 (dialogue log in docs/reports/T-4961-driver-sets.md)
- **IW-2: What is the narrowest design that clears the four blocking points (estimator collision, D1-D4 scoping, weight caps, bvp.sh reading only the live file)?**
  confidence: 0
  disposition: deferred
  rationale: design read next, then a short independent review (docs/reports/T-4961-driver-sets.md)

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
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** GO — narrow form

**Rationale:**

Operator, 2026-11-01, in chat: chose "GO, narrow". Scope: only the loading path. `driver_set:` on an arc (a task inherits its arc's set) resolves to `policy/value-drivers-<set>.yaml` and is read by bvp ranking and the estimator, with weights and caps per set. D1-D4 keep their meaning. No new gates. A design read of the four blocking points below and a short independent review come first, then build slices. Recording the decision itself stays the operator's, via Watchtower.

Filing-time note (kept): not yet explored. 010-termlink (msg c39df4cd) asks that an arc or task name a driver set resolving to policy/value-drivers-<set>.yaml, used by bvp.sh ranking and the estimator, with D1-D4 meaning unchanged and weights per set. Today the live file wins collisions (estimator.py:2727-2736), D1-D4 cannot be scoped (arc-driver-review.sh check_b), scoped weights are capped (arc.sh:1567,1624) and bvp rank reads only the live file (bvp.sh:285-364). Needs a design read of those four points and the operator's view on whether two driver sets per project is wanted before GO or NO-GO; the peer scores by hand meanwhile, so nothing is blocked.

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

**Decision**: GO

**Rationale**: Operator, 2026-11-01, in chat: chose "GO, narrow". Scope: only the loading path. `driver_set:` on an arc (a task inherits its arc's set) resolves to `policy/value-drivers-<set>.yaml` and is read by bvp ranking and the estimator, with weights and caps per set. D1-D4 keep their meaning. No new gates. A design read of the four blocking points below and a short independent review come first, then build slices. Recording the decision itself stays the operator's, via Watchtower.

Filing-time note (kept): not yet explored. 010-termlink (msg c39df4cd) asks that an arc or task name a driver set resolving to policy/value-drivers-<set>.yaml, used by bvp.sh ranking and the estimator, with D1-D4 meaning unchanged and weights per set. Today the live file wins collisions (estimator.py:2727-2736), D1-D4 cannot be scoped (arc-driver-review.sh check_b), scoped weights are capped (arc.sh:1567,1624) and bvp rank reads only the live file (bvp.sh:285-364). Needs a design read of those four points and the operator's view on whether two driver sets per project is wanted before GO or NO-GO; the peer scores by hand meanwhile, so nothing is blocked.

**Date**: 2026-11-01T14:47:58Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-01T14:37:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-01T14:47:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Operator, 2026-11-01, in chat: chose "GO, narrow". Scope: only the loading path. `driver_set:` on an arc (a task inherits its arc's set) resolves to `policy/value-drivers-<set>.yaml` and is read by bvp ranking and the estimator, with weights and caps per set. D1-D4 keep their meaning. No new gates. A design read of the four blocking points below and a short independent review come first, then build slices. Recording the decision itself stays the operator's, via Watchtower.

Filing-time note (kept): not yet explored. 010-termlink (msg c39df4cd) asks that an arc or task name a driver set resolving to policy/value-drivers-<set>.yaml, used by bvp.sh ranking and the estimator, with D1-D4 meaning unchanged and weights per set. Today the live file wins collisions (estimator.py:2727-2736), D1-D4 cannot be scoped (arc-driver-review.sh check_b), scoped weights are capped (arc.sh:1567,1624) and bvp rank reads only the live file (bvp.sh:285-364). Needs a design read of those four points and the operator's view on whether two driver sets per project is wanted before GO or NO-GO; the peer scores by hand meanwhile, so nothing is blocked.

### 2026-11-01T14:47:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b829ee8e
- **Timestamp:** 2026-11-01T14:48:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-0c9ea17c
- **Timestamp:** 2026-11-01T14:48:00Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation
