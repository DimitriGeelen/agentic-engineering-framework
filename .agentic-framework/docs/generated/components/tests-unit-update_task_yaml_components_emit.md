# update_task_yaml_components_emit

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/update_task_yaml_components_emit.bats`

## What It Does

T-1469: update-task.sh auto-populate components path used a sed line replace
that left orphan `  - item` continuation lines from block-style components,
producing invalid YAML. This caused Watchtower's scanner to crash on parse,
rendering empty queues for the human (T-1468 cleanup).
This test pins the fix by:
1. Seeding a task with block-style `components:\n  - X\n  - Y\n`
2. Seeding a fabric card whose location matches a file the commit touched
3. Running `update-task.sh --status work-completed` (triggers the auto-pop)
4. Asserting the resulting YAML parses cleanly AND has no orphan `  - ` lines

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/update-task.sh` | calls |
| `agents/task-create/update-task.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-update_task_yaml_components_emit.yaml`*
*Last verified: 2026-04-25*
