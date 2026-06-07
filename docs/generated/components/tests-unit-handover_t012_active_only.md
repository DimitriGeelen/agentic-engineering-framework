# handover_t012_active_only

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/handover_t012_active_only.bats`

## What It Does

T-1477 — handover.sh's COMMIT_TASK lookup must only match T-012 when it is
in .tasks/active/. Matching completed/ caused recurring "task is closed"
warnings on every session handover commit because T-012 was completed long
ago.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [handover](/docs/generated/agents-handover-handover) | tests | Handover Agent - Mechanical Operations |

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_t012_active_only.yaml`*
*Last verified: 2026-04-25*
