---
id: T-475
name: "Add bats tests for 9 uncovered gate scripts"
description: >
  Write ~55 new bats tests covering: budget-gate.sh (15), block-plan-mode.sh (3),
  check-dispatch.sh (5), check-fabric-new-file.sh (5), checkpoint.sh (8), bus-handler.sh
  (5), pre-compact.sh (5), post-compact-resume.sh (5). Follow existing test_helper.bash
  patterns. Phase 2 of T-473 GO.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [testing, D2]
components: []
related_tasks: []
created: 2026-03-12T21:31:04Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-13T07:25:29Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-475: Add bats tests for 9 uncovered gate scripts

## Context

Phase 2 of T-473 GO (Option B+). Research report: `docs/reports/T-473-bash-unit-test-inception.md`. Priority order by risk x effort: budget-gate.sh (highest risk), block-plan-mode.sh (trivial), check-dispatch.sh, check-fabric-new-file.sh. Remaining scripts (checkpoint.sh, bus-handler.sh, pre/post-compact) are lower priority and may be deferred.

## Acceptance Criteria

### Agent
- [x] tests/integration/budget_gate.bats exists with 16 tests covering: ok/warn/urgent/critical fast path, Read/Glob/Grep exempt, git commit/fw handover exempt, wrap-up paths (.context/.tasks/.claude/), stale cache fallthrough, no-status failsafe
- [x] tests/integration/block_plan_mode.bats exists with 4 tests: block exit 2, /plan alternative, BLOCKED message, governance bypass
- [x] tests/integration/check_dispatch.bats exists with 8 tests: non-Task silent, small response silent, >5K WARNING, >20K CRITICAL, TaskOutput, empty response, preamble mention, malformed JSON
- [x] tests/integration/check_fabric_new_file.bats exists with 8 tests: non-Write silent, skip prefixes, no patterns file, no match, advisory match, already registered, never blocks
- [x] All existing tests still pass: 187/187 (151 original + 36 new)
- [x] Each test file follows test_helper.bash patterns (setup/teardown, temp dirs, TASKS_DIR/CONTEXT_DIR exports)

## Verification

bats tests/integration/ tests/unit/

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-12T21:31:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-475-add-bats-tests-for-9-uncovered-gate-scri.md
- **Context:** Initial task creation

### 2026-03-13T07:20:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-13T07:25:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e9e92796
- **Timestamp:** 2026-06-02T15:03:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 5

**Per-AC findings:**

- **AC#1 (Agent)** — tests/integration/budget_gate.bats exists with 16 tests covering: ok/warn/urgent/critical fast path, Read/Glob/Grep exempt, git commit/fw handover exempt, wrap-up paths (.context/.tasks/.claude/), sta
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/integration/budget_gate.bats in: tests/integration/budget_gate.bats exists with 16 tests covering: ok/warn/urgent/critical fast path, Read/Glob/Grep exempt, git commit/fw handover exe`
- **AC#2 (Agent)** — tests/integration/block_plan_mode.bats exists with 4 tests: block exit 2, /plan alternative, BLOCKED message, governance bypass
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/integration/block_plan_mode.bats in: tests/integration/block_plan_mode.bats exists with 4 tests: block exit 2, /plan alternative, BLOCKED message, governance bypass`
- **AC#3 (Agent)** — tests/integration/check_dispatch.bats exists with 8 tests: non-Task silent, small response silent, >5K WARNING, >20K CRITICAL, TaskOutput, empty response, preamble mention, malformed JSON
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/integration/check_dispatch.bats in: tests/integration/check_dispatch.bats exists with 8 tests: non-Task silent, small response silent, >5K WARNING, >20K CRITICAL, TaskOutput, empty respo`
- **AC#4 (Agent)** — tests/integration/check_fabric_new_file.bats exists with 8 tests: non-Write silent, skip prefixes, no patterns file, no match, advisory match, already registered, never blocks
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/integration/check_fabric_new_file.bats in: tests/integration/check_fabric_new_file.bats exists with 8 tests: non-Write silent, skip prefixes, no patterns file, no match, advisory match, already`

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/integration/ tests/unit/`
