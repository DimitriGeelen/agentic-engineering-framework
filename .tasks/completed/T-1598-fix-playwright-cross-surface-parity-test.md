---
id: T-1598
name: "Fix Playwright cross-surface parity test — replace decaying T-967 negative-case
  fixture (T-1597 follow-up)"
description: >
  Cross-surface parity invariant test (tests/playwright/test_cross_surface_parity.py)
  ships TASK_WITHOUT_REVIEWER='T-967' as the negative case. The daily reviewer scan
  systematically writes ## Reviewer Verdict blocks back into completed tasks — T-967
  acquired one 16 min after T-1586 completed. Test now fails 1/8 (negative case).
  Fix: replace the static fixture with a self-renewing approach (synthetic in-test
  task body OR Jinja2-rendered template OR pick a no-reviewer task at runtime). Surfaced
  by T-1597 blind-reviewer sweep, W3.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-29T07:34:08Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T18:21:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1598: Fix Playwright cross-surface parity test — replace decaying T-967 negative-case fixture (T-1597 follow-up)

## Context

T-967 acquired a `## Reviewer Verdict` block via the daily reviewer scan after T-1586 shipped, breaking the negative-case assertion in `tests/playwright/test_cross_surface_parity.py::test_reviewer_block_absent_when_body_has_no_block`. Static fixtures decay because the reviewer agent rewrites all completed/active tasks. Fix: dynamically pick a no-reviewer task at runtime via a pytest fixture that scans `.tasks/` for one without the block — self-renewing as the population shifts.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_cross_surface_parity.py` no longer references the static `TASK_WITHOUT_REVIEWER = "T-967"` constant for the negative case — replaced with a pytest fixture (`task_without_reviewer`) that resolves a task ID at runtime
- [x] The fixture scans `.tasks/active/` and `.tasks/completed/` for a task whose body has no `## Reviewer Verdict` heading and returns its ID (preferring completed for stability); if none exist, the fixture raises `pytest.skip` with a clear message
- [x] `bin/fw test playwright -- tests/playwright/test_cross_surface_parity.py` exits 0 — all 8 tests pass (including the negative case)
- [x] No other test file references `T-967` as a no-reviewer fixture (verified via grep)

## Verification

bin/fw test playwright -- tests/playwright/test_cross_surface_parity.py
test "$(grep -rn 'TASK_WITHOUT_REVIEWER.*T-967' tests/playwright/ | wc -l)" = "0"

## RCA

**Symptom:** `test_reviewer_block_absent_when_body_has_no_block` failed because T-967 (the static `TASK_WITHOUT_REVIEWER` fixture) acquired a `## Reviewer Verdict` block 16 minutes after T-1586 shipped.

**Root cause:** Static task-ID fixtures pinned in test source decay because the daily reviewer scan rewrites all reachable task bodies. The negative-case assertion (no reviewer block) holds for at most one reviewer-scan window after the fixture is chosen.

**Why structurally allowed:** The test ran green on the day it was written; nothing in the test suite or reviewer agent flagged the silent invariant inversion. The test only fails after the fixture decays, which is detected via the `fw test playwright` cron — fast-failing, but only for one task.

**Prevention:** Replace static fixture with runtime-resolved one. The `task_without_reviewer` pytest fixture re-scans `.tasks/{completed,active}` each session — as the population shifts, the fixture follows it. If every task acquires a verdict, the test skips with a clear message rather than failing falsely.

## Recommendation

**Recommendation:** GO
**Rationale:** All 8 tests pass; static fixture replaced with runtime fixture; no other test references `T-967` as a no-reviewer fixture (verified via grep).
**Evidence:**
- `bin/fw test playwright -- tests/playwright/test_cross_surface_parity.py` → 8 passed in 7.53s
- `grep -rn 'TASK_WITHOUT_REVIEWER.*T-967' tests/playwright/` → 0 matches
- T-1586 cross-surface parity invariant now self-renewing

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

### 2026-04-29T07:34:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1598-fix-playwright-cross-surface-parity-test.md
- **Context:** Initial task creation

### 2026-04-29T07:34:42Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-29T18:19:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b92b9486
- **Timestamp:** 2026-06-02T14:58:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T18:21:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
