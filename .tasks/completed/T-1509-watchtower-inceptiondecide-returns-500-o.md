---
id: T-1509
name: "Watchtower /inception/decide returns 500 on partial-complete success — record_decision misreads stdout (split from T-1503)"
description: >
  Split from T-1503 P-010. update-task.sh exits non-zero in post-transition path under set -euo pipefail (auto-decisions, components resolver, learning detector, or similar). web/blueprints/inception.py:411 record_decision treats non-zero exit as failure → 500 to user. Underlying transition succeeded. Fix area: defensive parse of stdout success markers in record_decision + RCA the spurious non-zero exit in update-task.sh post-transition path.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/inception.sh, lib/review.sh, tests/unit/inception_decide_atomicity.bats]
related_tasks: []
created: 2026-04-26T12:05:09Z
last_update: 2026-04-26T13:14:13Z
date_finished: 2026-04-26T13:14:13Z
---

# T-1509: Watchtower /inception/decide returns 500 on partial-complete success — record_decision misreads stdout (split from T-1503)

## Context

RCA isolated the non-zero exit. `lib/inception.sh:318` resolves `task_file` to the `active/` path. Line 494 (`update-task.sh --status work-completed`) then moves the file to `completed/`. Line 508 calls `emit_review "$task_id" "$task_file"` with the now-stale `active/` path. `emit_review` checks `[ ! -f "$task_file" ]` (lib/review.sh:36) → `return 1` → `set -e` aborts the function → `bin/fw inception decide` exits non-zero → Watchtower's `record_decision` sees `ok=False` despite the primary decision having landed cleanly.

Validated by trap on `set -Eeuo pipefail` ERR — failure pinpointed to `lib/inception.sh:508` `BASH_COMMAND=return 1 FUNCNAME=do_inception_decide` (i.e. `return 1` raised from inside `emit_review`).

User-visible symptom: "⚠ Decision recorded; side-effect warning: === Task Update ===..." (the leaked first 150 chars of `update-task.sh`'s normal banner output, surfaced as if it were an error).

## Acceptance Criteria

### Agent
- [x] `lib/review.sh:emit_review` falls back to discovery when the passed `task_file` arg is invalid (empty OR points at a non-existent path), instead of `return 1`. Discovery searches both `active/` and `completed/`.
- [x] `lib/inception.sh` no longer passes a stale `active/` path to `emit_review` after `update-task.sh` has moved the task to `completed/`. Either re-resolve the path post-move OR omit the arg and rely on discovery.
- [x] New regression test `tests/unit/inception_decide_emit_review_post_move.bats` reproduces the bug pre-fix (red) and confirms `do_inception_decide` exits 0 post-fix on a successful go decision (green).
- [x] Existing `inception_decide_atomicity.bats` and `hook_enable_absolute_path.bats` still pass.

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Decide an inception via Watchtower (e.g. T-1501 or T-1502) and confirm no side-effect warning appears
  **Steps:**
  1. Open http://192.168.10.107:3000/inception/T-XXXX (any captured pickup with ACs filled)
  2. Click GO with a rationale
  3. Watch the response card — it should show only "Decision recorded — GO" with no `⚠ side-effect warning` line
  4. Tail Watchtower log to confirm no ERROR logged for `inception decide ... failed`
  **Expected:** Clean decision card, no warning, exit 0 from `fw inception decide`
  **If not:** The fix didn't land or there's a second failure path — capture the warning text and re-open T-1509

## Verification

# Regression tests pass (covers the post-move emit_review fix)
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/inception_decide_emit_review_post_move.bats
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/inception_decide_atomicity.bats

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

### 2026-04-26T12:05:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1509-watchtower-inceptiondecide-returns-500-o.md
- **Context:** Initial task creation

### 2026-04-26T12:05:21Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-04-26T13:08:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-935affd5
- **Timestamp:** 2026-06-02T14:57:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T13:14:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
