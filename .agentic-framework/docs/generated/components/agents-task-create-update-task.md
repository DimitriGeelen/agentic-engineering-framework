# update-task

> Task Update Agent - Status transitions with auto-triggers

**Type:** script | **Subsystem:** task-management | **Location:** `agents/task-create/update-task.sh`

## What It Does

Task Update Agent - Status transitions with auto-triggers
Updates task frontmatter and triggers structural actions:
issues/blocked  → auto-diagnose via healing agent
work-completed  → set date_finished, move to completed/, generate episodic
Usage:
./agents/task-create/update-task.sh T-XXX --status issues
./agents/task-create/update-task.sh T-XXX --status work-completed
./agents/task-create/update-task.sh T-XXX --owner claude-code
./agents/task-create/update-task.sh T-XXX --status blocked --reason "Waiting on API key"

## Dependencies (7)

| Target | Relationship |
|--------|-------------|
| `C-001` | calls |
| `agents/healing/healing.sh` | calls |
| `lib/paths.sh` | calls |
| `lib/enums.sh` | calls |
| `lib/keylock.sh` | calls |
| `lib/review.sh` | calls |
| `lib/notify.sh` | calls |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `C-004` | called_by |
| `bin/fw` | called_by |
| `agents/audit/audit.sh` | called-by |
| `tests/unit/update_task.bats` | tested_by |
| `tests/unit/update_task.bats` | called_by |

## Documentation

- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-795: Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-task-create-update-task.yaml`*
*Last verified: 2026-02-20*
