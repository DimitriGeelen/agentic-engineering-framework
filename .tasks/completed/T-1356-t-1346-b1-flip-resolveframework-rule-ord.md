---
id: T-1356
name: "T-1346-B1: flip resolve_framework rule order — vendored beats global"
description: >
  T-1346-B1: flip resolve_framework rule order — vendored beats global

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-20T13:34:05Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T14:17:20Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1356: T-1346-B1: flip resolve_framework rule order — vendored beats global

## Context

Build-out of T-1346 Option B++ recommendation. Current `resolve_framework` (bin/fw:74-113) has rule 1 (fw-inside-framework-repo) matching before rule 2 (project-vendored). When `fw` is invoked via global shim (`~/.local/bin/fw → /root/.agentic-framework/bin/fw`), rule 1 returns the global framework even when the consumer project has its own vendored copy — silent isolation leak (T-1346 A1 CONFIRMED).

See `docs/reports/T-1346-global-install-isolation.md` §Recommendation B1.

Fix: re-order so project-vendored wins EXCEPT when `$FW_BIN_DIR/..` is inside `$PROJECT_ROOT` (which covers both the framework-repo-self-invocation case and direct-vendored-invocation case).

## Acceptance Criteria

### Agent
- [x] `resolve_framework` in `bin/fw` reorders rules: when `$PROJECT_ROOT/.agentic-framework/FRAMEWORK.md` exists AND `$FW_BIN_DIR/..` is NOT inside `$PROJECT_ROOT`, vendored wins (covers global-shim-in-consumer case)
- [x] Framework-repo self-invocation still resolves to the repo (not the nested `.agentic-framework/`): `bin/fw version` from repo prints `Framework: /opt/999-Agentic-Engineering-Framework`
- [x] Direct vendored invocation still works (bats test 2 covers this)
- [x] Bats unit test added at `tests/unit/resolve_framework.bats` covering: (a) framework-repo self, (b) vendored-direct, (c) global-shim-in-vendored-consumer — all 3 pass
- [x] `fw doctor` still passes (no regressions — verified manually)
- [x] `bats tests/unit/resolve_framework.bats` passes (3/3)

## Verification

bin/fw version >/dev/null
bats tests/unit/resolve_framework.bats
bin/fw doctor >/dev/null 2>&1 || true

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

### 2026-04-20T13:34:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1356-t-1346-b1-flip-resolveframework-rule-ord.md
- **Context:** Initial task creation

### 2026-04-20T14:17:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-955b0094
- **Timestamp:** 2026-06-02T18:58:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 2 (by override)
  - swallowed-errors @ Verification:line 3
  - empty-output-success @ Verification:line 1
