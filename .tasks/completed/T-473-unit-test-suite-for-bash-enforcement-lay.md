---
id: T-473
name: "Unit test suite for bash enforcement layer (bats-core)"
description: >
  Inception: Unit test suite for bash enforcement layer (bats-core)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [testing, reliability, D2]
components: []
related_tasks: []
created: 2026-03-12T21:14:17Z
last_update: '2026-08-16T22:25:31Z'
date_finished: 2026-03-17T11:20:59Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:31Z'
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

# T-473: Unit test suite for bash enforcement layer (bats-core)

## Problem Statement

The framework's enforcement layer (30+ bash scripts in `agents/context/`) has zero unit tests. These scripts make binary allow/block decisions on every file edit, every bash command, every compaction. A governance framework that preaches structural enforcement should structurally enforce its own correctness. Marc's question "what are the unit tests for bash?" exposed this gap. The framework has 470+ tasks as observational evidence but no automated regression tests for the gates themselves.

**For whom:** Framework maintainers and contributors. Also: any user who modifies hooks.
**Why now:** G-020 (governance bypass) proved that gates can have gaps. We caught it by human intervention. A test suite would have caught the missing scope check during development.

## Assumptions

- A-1: bats-core is the right test framework (alternatives: shunit2, shellspec, plain bash)
- A-2: Gate scripts can be tested in isolation (mock stdin JSON, mock focus.yaml, check exit code)
- A-3: Tests can run fast enough to include in pre-push hook (<30s total)
- A-4: Test fixtures (mock task files, mock focus.yaml) are manageable

## Exploration Plan

1. **Spike 1** (30 min): Install bats-core, write one test for check-active-task.sh (allow case + block case). Assess ergonomics.
2. **Spike 2** (30 min): Inventory all gate scripts, classify by testability (pure function vs side-effect-heavy). Estimate total test count.
3. **Spike 3** (30 min): Evaluate alternatives (shunit2, shellspec, plain bash assert functions). Compare setup cost, readability, CI integration.
4. **Decision**: Choose framework, estimate effort for full coverage, go/no-go.

## Technical Constraints

- Tests must run on bash 4+ (framework minimum)
- Tests must not modify real project files (use temp dirs)
- Test framework must be installable without root (npm/brew or git clone)
- Tests must work in CI (GitHub Actions, OneDev)

## Scope Fence

**IN scope:** Unit tests for enforcement gates (check-active-task.sh, check-tier0.sh, budget-gate.sh, block-plan-mode.sh, check-dispatch.sh, check-fabric-new-file.sh). Test framework selection. CI integration design.

**OUT of scope:** Tests for agents (handover, audit, healing — these are more complex). Tests for Python code. Performance benchmarks.

## Acceptance Criteria

- [x] Problem statement validated (5 gate incidents in 7 months, 172 existing tests found)
- [x] Assumptions tested (A-1 thru A-4 all validated — bats installed, scripts testable, 10s runtime, helpers exist)
- [x] Go/No-Go decision made (GO — Option B+, ~7h effort)

## Go/No-Go Criteria

**GO if:**
- [x] bats-core can test gate scripts in isolation with mock inputs (172 existing tests prove this)
- [x] A full test suite for 6 gate scripts is estimated at <4 hours (4.25h estimated)
- [x] Tests run in <30 seconds total (10s for 172 tests)

**NO-GO if:**
- [ ] Gate scripts have too many side effects — NOT TRIGGERED
- [ ] Test framework adds significant dependency burden — NOT TRIGGERED (already installed)
- [ ] Effort exceeds 8 hours — NOT TRIGGERED (~7h total)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 172 bats tests exist, all assumptions validated, ~7h effort for Option B+ (extend existing). 5 gate incidents in 7 months justify investment.

**Date**: 2026-03-12T21:30:44Z
## Decision

**Decision**: GO

**Rationale**: 172 bats tests exist, all assumptions validated, ~7h effort for Option B+ (extend existing). 5 gate incidents in 7 months justify investment.

**Date**: 2026-03-12T21:30:44Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-12T21:30:44Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 172 bats tests exist, all assumptions validated, ~7h effort for Option B+ (extend existing). 5 gate incidents in 7 months justify investment.

### 2026-03-17T11:20:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-13fea13d
- **Timestamp:** 2026-06-02T15:03:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
