# create-task

> Task Creation Agent - Mechanical Operations

**Type:** script | **Subsystem:** task-management | **Location:** `agents/task-create/create-task.sh`

## What It Does

Task Creation Agent - Mechanical Operations
Creates properly structured tasks following the framework specification

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `agents/handover/handover.sh` | called_by |
| `agents/observe/observe.sh` | called_by |
| `bin/fw` | called_by |
| `lib/setup.sh` | called_by |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

## Related

### Tasks
- T-165: Fix 20 broken Watchtower task links — YAML quoting bugs in task and episodic files
- T-297: Fix --start flag not setting focus in create-task.sh

---
*Auto-generated from Component Fabric. Card: `agents-task-create-create-task.yaml`*
*Last verified: 2026-02-20*
