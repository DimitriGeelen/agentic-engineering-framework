# create-task

> Task Creation Agent - Mechanical Operations

**Type:** script | **Subsystem:** task-management | **Location:** `agents/task-create/create-task.sh`

## What It Does

Task Creation Agent - Mechanical Operations
Creates properly structured tasks following the framework specification

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `lib/paths.sh` | calls |
| `lib/enums.sh` | calls |
| `lib/keylock.sh` | calls |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `agents/handover/handover.sh` | called_by |
| `agents/observe/observe.sh` | called_by |
| `bin/fw` | called_by |
| `lib/setup.sh` | called_by |
| `tests/unit/create_task.bats` | tested_by |
| `tests/unit/create_task.bats` | called_by |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

## Related

### Tasks
- T-795: Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-task-create-create-task.yaml`*
*Last verified: 2026-02-20*
