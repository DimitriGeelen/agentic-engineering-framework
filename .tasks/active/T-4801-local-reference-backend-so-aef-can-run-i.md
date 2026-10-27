---
id: T-4801
name: "Local reference backend so AEF can run its own worker-contract conformance
  vectors"
description: >
  Inception: Local reference backend so AEF can run its own worker-contract conformance
  vectors

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-27T09:24:50Z
last_update: '2026-10-27T09:30:20Z'
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
  - ts: '2026-10-27T09:25:36Z'
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
  - ts: '2026-10-27T09:30:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=136,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4801: Local reference backend so AEF can run its own worker-contract conformance vectors

## Problem Statement

AEF wrote and owns the shared dispatched-worker contract (wc/0.3.x) and its conformance vectors. Yet AEF is the one party that cannot run them: `tests/conformance/worker-contract/run_local.py` reports every case not-implemented, because `lib/dispatch_records.py` (the §6.2 dispatch records) does not exist. ring20 passes 19 cases mechanically and TermLink has a Rust implementation. AEF's own `fw termlink dispatch` workers run outside the contract (dispatches.jsonl, run.sh exit_code/close_state). The question: should AEF build a local backend that implements the contract's records and transitions, and if so how much of it, and for which purpose? The purposes in play are self-conformance of the reference, real use by fw termlink dispatch, or both.

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

- **IW-1: What does a "local backend" have to provide to run the vectors (§6, the adapter interface in run_local.py), and how much of it already exists in fw termlink dispatch?**
  confidence: 3
  disposition: answered
  rationale: spec §6.1–6.5 designs it (one record per dispatch, flock+CAS, local liveness probe for lost) and run_local.py:52-81 fixes the adapter entry point. fw termlink dispatch has only the evidence half (run.sh exit_code/close_state, dispatches.jsonl ledger) and none of the §3 state machine. See docs/reports/T-4801-local-reference-backend.md Findings 2-3
- **IW-2: Which purpose: a test-only reference model (proves the vectors are passable and keeps them honest), or the real record store behind fw termlink dispatch (AEF's own workers become contract-conformant)?**
  confidence: 2
  disposition: answered
  rationale: both, in order. T-4435 conditions 3 and 4 already set the sequence: first the store judged by the suite (option A), then shadow-writing from real dispatches (B), then switch-over only after shadow evidence (C). The operator confirms by the decision on this inception

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
**GO (for a slice) if:**
- The slice is already covered by an earlier GO, or is bounded and judged by an existing test (the vectors)
- The slice changes nothing an operator or another project relies on (no change to fw termlink dispatch behaviour)

**NO-GO (for a slice) if:**
- It moves the completion authority before shadow evidence exists (T-4435 condition 4)
- It needs a spec change that is not yet agreed by all three parties

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

**Recommendation:** GO, for option A (store + conformance adapter only) as the next slice

**Rationale:**

The research changed the question. T-4435 (GO 2026-10-20) already decided AEF builds a local backend with the same CAS semantics, run against the same conformance suite (condition 3), with no implementation until the transition table was agreed (condition 1). That precondition is now met: spec v0.3.3 is agreed and the vectors run mechanically against ring20. Spec §6 already designs the store: one JSON file per dispatch, flock + CAS on every write, and a local liveness probe for `lost`. Option A builds only `lib/dispatch_records.py` and its `conformance_adapter()`, judged by the existing vectors. It changes nothing in fw termlink dispatch. Shadow-writing from real dispatches (B) and moving the completion authority (C) stay later decisions, as T-4435 condition 4 requires (shadow mode before switch-over).

**Evidence:**
- docs/reports/T-4801-local-reference-backend.md: findings, the options table and the dialogue log
- .tasks/completed/T-4435-*.md: Decision GO, conditions 1, 3 and 4
- docs/specs/shared-worker-contract-transitions.md §6.1–6.5: the local backend mechanism
- tests/conformance/worker-contract/run_local.py:52-81: the loader expects lib/dispatch_records.py `conformance_adapter()`

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

### 2026-10-27T09:25:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
