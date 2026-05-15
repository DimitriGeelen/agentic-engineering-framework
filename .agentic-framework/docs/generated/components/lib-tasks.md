# tasks

> fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/tasks.sh`

## What It Does

lib/tasks.sh — Shared task file lookup helpers
Provides find_task_file() and task_exists() to replace the
find ... -name "${task_id}-*.md" pattern duplicated across 7+ files.
Usage: source "$FRAMEWORK_ROOT/lib/tasks.sh"
Requires: TASKS_DIR (set by lib/paths.sh)

### Framework Reference

When starting work (**BEFORE reading code, editing files, or invoking skills**):
1. Check for existing task or create new one following `zzz-default.md` template
2. Set status to `started-work`
3. Set focus: `fw context focus T-XXX`
4. THEN proceed with implementation (skills, code changes, etc.)
5. Record decisions in Decisions section ONLY when choosing between alternatives
6. Updates section is auto-populated at completion — manual entries optional

*(truncated — see CLAUDE.md for full section)*

## Used By (22)

| Component | Relationship |
|-----------|-------------|
| `agents/git/lib/hooks.sh` | called_by |
| `bin/fw` | called_by |
| `lib/paths.sh` | called_by |
| `tests/unit/lib_tasks.bats` | called-by |
| `tests/unit/lib_tasks.bats` | called_by |
| `tests/unit/context_episodic.bats` | called_by |
| `tests/unit/context_episodic.bats` | tests_by |
| `tests/unit/context_focus.bats` | called_by |
| `tests/unit/context_focus.bats` | tests_by |
| `tests/unit/git_common.bats` | called_by |
| `tests/unit/git_common.bats` | tests_by |
| `tests/unit/inception_decide_ac_tick.bats` | called_by |
| `tests/unit/inception_decide_ac_tick.bats` | tests_by |
| `tests/unit/inception_decide_atomicity.bats` | called_by |
| `tests/unit/inception_decide_atomicity.bats` | tests_by |
| `tests/unit/inception_tick_decision_recorded.bats` | called_by |
| `tests/unit/inception_tick_decision_recorded.bats` | tests_by |
| `tests/unit/inception_tick_marker.bats` | called_by |
| `tests/unit/inception_tick_marker.bats` | tests_by |
| `tests/unit/lib_inception.bats` | called_by |
| `tests/unit/lib_inception.bats` | tests_by |
| `tests/unit/lib_tasks.bats` | tests_by |

---
*Auto-generated from Component Fabric. Card: `lib-tasks.yaml`*
*Last verified: 2026-03-11*
