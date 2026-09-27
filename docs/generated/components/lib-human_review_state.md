# human_review_state

> Classifies a task file's '### Human' AC blocks for the P-013 render gate (prints has_review/only_other/empty/no_section/error); single source of truth extracted from update-task.sh (T-3288)

**Type:** script | **Subsystem:** task-management | **Location:** `lib/human_review_state.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `lib-human_review_state.yaml`*
*Last verified: 2026-09-08*
