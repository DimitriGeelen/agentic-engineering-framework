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

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `agents/git/lib/hooks.sh` | called_by |
| `bin/fw` | called_by |
| `lib/paths.sh` | called_by |
| `tests/unit/lib_tasks.bats` | called-by |
| `tests/unit/lib_tasks.bats` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-tasks.yaml`*
*Last verified: 2026-03-11*
