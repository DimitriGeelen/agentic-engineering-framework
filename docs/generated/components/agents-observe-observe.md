# observe

> Observe Agent - Lightweight observation capture

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/observe/observe.sh`

## What It Does

Observe Agent - Lightweight observation capture
The fastest path from "I noticed something" to "it's recorded"
Usage:
./agents/observe/observe.sh "observation text"           # Capture
./agents/observe/observe.sh "text" --tag bug --task T-XX # Capture with context
./agents/observe/observe.sh list                         # Show pending
./agents/observe/observe.sh count                        # Pending count
./agents/observe/observe.sh promote OBS-001              # Promote to task
./agents/observe/observe.sh dismiss OBS-001 --reason "..." # Dismiss
./agents/observe/observe.sh triage                       # Interactive review

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/create-task.sh` | calls |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

## Related

### Tasks
- T-348: Fix update-task.sh sed failing on macOS BSD sed

---
*Auto-generated from Component Fabric. Card: `agents-observe-observe.yaml`*
*Last verified: 2026-02-20*
