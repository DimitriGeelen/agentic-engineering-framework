---
id: T-5212
name: "Batch task creation: reserve a block of task ids and an arc id in one call,
  create an arc with its tasks from a template in one call, with a reservation ledger
  (1409 request)"
description: >
  Inception: Batch task creation: reserve a block of task ids and an arc id in one
  call, create an arc with its tasks from a template in one call, with a reservation
  ledger (1409 request)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-11-17T21:15:57Z
last_update: 2026-11-17T23:17:24Z
date_finished: 2026-11-17T23:17:24Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-11-17T21:16:36Z'
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
  - ts: '2026-11-17T21:30:32Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=129,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5212: Batch task creation: reserve a block of task ids and an arc id in one call, create an arc with its tasks from a template in one call, with a reservation ledger (1409 request)

## Problem Statement

1409 (sidecar 131579aa, 0e42d876, 8ba662ce, f3e548ce; 2026-11-17) creates the same governance for every municipality: one arc with 13 step tasks from a template. That is 14 separate create calls per unit. They measured 52 s per unit, 43 minutes for a wave of 50. Of each ~3.7 s call, 2.0-2.5 s goes to `generate_id`, which union-scans `.tasks/` across all 24 git worktrees of their repo (agents/task-create/create-task.sh, T-100202) under one lock. Parallel calls are safe but serialised. Their operator wants the whole pattern created in one go, foolproof and reconcilable, and 1409 will not write around the framework. Research: docs/reports/T-5212-batch-task-creation.md.

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

- **IW-1: Reservation: can one call reserve a contiguous block of task ids plus an arc id (one scan, one lock) with a ledger (range, purpose, time, reserved -> created/complete) that reconciliation reads, so a reserved id without a file is reported as an incomplete arc and never reissued?**
  confidence: 3
  disposition: answered
  rationale: Operator, 2026-11-18 ("all yes" to proposal 4). Yes: one call reserves a block of at most 100 ids under the existing lock, and an append-only ledger records each reservation. Reconciliation reports a reserved id without a file and never reissues it. Proven in 1409's prototype (2,020 concurrent allocations, 0 duplicates; kill -9 mid-block, no reuse). No arc-id reservation: 1409's arc ids are fixed names.
- **IW-2: Quarantine trap: generate_id stops at the first gap > FW_ID_QUARANTINE_GAP (1000). How does the rule read the ledger so that a large, partly unused block never pushes later ids into quarantine?**
  confidence: 3
  disposition: answered
  rationale: Operator, 2026-11-18 ("all yes" to proposal 5). Ledger ids count as used in the gap walk, blocks are at most 100, and the walk starts from the counter. 1409's check 2f (12 aborted 100-blocks) passed, and a 101-block is refused.
- **IW-3: Creation: one verb that creates an arc and its tasks from a template plus parameters, producing files identical to what create-task makes one by one. Which per-call side effects (fabric, episodic, focus, cap warnings, hooks) run once per batch, and which must still run per task?**
  confidence: 3
  disposition: answered
  rationale: Operator, 2026-11-18 ("all yes" to proposal 6). `fw arc instantiate` sits on top of a create-batch path, with one writer of task files shared with create-task, so the files are identical (1409 check 3a: 0 differences). Per-batch side effects run once. Focus/--start and inception tasks are refused in a batch.
- **IW-4: Scan cost: can the union scan across many worktrees be cached per view (invalidated on change) without weakening the duplicate-id guard, as a separate, smaller fix?**
  confidence: 2
  disposition: deferred
  rationale: Operator, 2026-11-18 ("all yes" to proposal 7). Not needed now: the union scan becomes a check run once per reservation (on by default), and 1409 archived 23 worktrees (2.91 s to 0.51 s per call). Revisit only if a project measures the per-reservation check as too slow.
- **IW-5: How do 1409's prototype and its six safety checks (20 concurrent processes, crash mid-block, stale view, deleted top id, old outlier band, equality with the single path) become this build's acceptance tests?**
  confidence: 3
  disposition: answered
  rationale: Operator, 2026-11-18 ("all yes" to proposal 8). Each of 1409's checks becomes a test in the build. `fw doctor` and `fw upgrade` assert one allocator per repository (mixed allocators are 1409's measured unsafe case; objectives-seed routes through it, T-5213). The ledger is tracked in git, so reconciliation works in a fresh clone.

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

**Recommendation:** GO

**Rationale:**

1409 measured 52 s per municipality (14 create calls at about 3.7 s, mostly the union scan of 24 worktrees in generate_id). A framework verb keeps one writer of task files (reliability, auditability); a reservation ledger with reconciliation makes it foolproof; the quarantine-gap rule must read the ledger so a large block never pushes later ids into quarantine. 1409 prototyped it in a copy, and every safety check passed. On a full-size replica (about 50k task files, 24 views), the time per unit (arc plus 13 tasks) fell from 95.2 s to 2.6 s, and a wave of 50 units takes 3.3 minutes. All IW questions were answered with the operator on 2026-11-18. Build slices if GO:
1. A single authoritative counter, block reservation and a ledger tracked in git, with reconciliation and the quarantine rule reading the ledger. objectives-seed routes through it (T-5213), and doctor and upgrade assert one allocator.
2. `fw task create-batch` with one writer of task files shared with create-task, and `fw arc instantiate` on top of it.

1409's checks become the acceptance tests. Research: docs/reports/T-5212-batch-task-creation.md.

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

**Rationale**: Recommendation: GO

Rationale:

1409 measured 52 s per municipality (14 create calls at about 3.7 s, mostly the union scan of 24 worktrees in generate_id). A framework verb keeps one writer of task files (reliability, auditability); a reservation ledger with reconciliation makes it foolproof; the quarantine-gap rule must read the ledger so a large block never pushes later ids into quarantine. 1409 prototyped it in a copy, and every safety check passed. On a full-size replica (about 50k task files, 24 views), the time per unit (arc plus 13 tasks) fell from 95.2 s to 2.6 s, and a wave of 50 units takes 3.3 minutes. All IW questions were answered with the operator on 2026-11-18. Build slices if GO:
1. A single authoritative counter, block reservation and a ledger tracked in git, with reconciliation and the quarantine rule reading the ledger. objectives-seed routes through it (T-5213), and doctor and upgrade assert one allocator.
2. `fw task create-batch` with one writer of task files shared with create-task, and `fw arc instantiate` on top of it.

1409's checks become the acceptance tests. Research: docs/reports/T-5212-batch-task-creation.md.

Evidence:

**Date**: 2026-11-17T23:17:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-17T21:16:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-17T23:17:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

1409 measured 52 s per municipality (14 create calls at about 3.7 s, mostly the union scan of 24 worktrees in generate_id). A framework verb keeps one writer of task files (reliability, auditability); a reservation ledger with reconciliation makes it foolproof; the quarantine-gap rule must read the ledger so a large block never pushes later ids into quarantine. 1409 prototyped it in a copy, and every safety check passed. On a full-size replica (about 50k task files, 24 views), the time per unit (arc plus 13 tasks) fell from 95.2 s to 2.6 s, and a wave of 50 units takes 3.3 minutes. All IW questions were answered with the operator on 2026-11-18. Build slices if GO:
1. A single authoritative counter, block reservation and a ledger tracked in git, with reconciliation and the quarantine rule reading the ledger. objectives-seed routes through it (T-5213), and doctor and upgrade assert one allocator.
2. `fw task create-batch` with one writer of task files shared with create-task, and `fw arc instantiate` on top of it.

1409's checks become the acceptance tests. Research: docs/reports/T-5212-batch-task-creation.md.

Evidence:

### 2026-11-17T23:17:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3b692be4
- **Timestamp:** 2026-11-17T23:17:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-1e2063f0
- **Timestamp:** 2026-11-17T23:17:27Z
- **Overall:** CONFIRMED
- **Claims:** 1

| Claim | Type | Status |
|-------|------|--------|
| `T-5213` | task | ✓ pass |
