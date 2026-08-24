# create_task_owner_gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/create_task_owner_gate.bats`

## What It Does

T-2674 — creation-side owner validation (residual G-040 hole).
is_valid_owner() has existed since T-1180 (lib/enums.sh, compiled from
status-transitions.yaml `owners:`) but create-task.sh never called it —
any --owner string was written verbatim while Watchtower's dropdowns and
update endpoints whitelist the enum. Surfaced by T-2666's task-creation
corpus map + 832's round-#3 pair-draft verdict (rail 316).
The enum was reconciled with live reality in the same task: `agent` (the
fw work-on default, 500+ live tasks) added to status-transitions.yaml
owners — the gate goes hard only against values outside {human,
claude-code, agent}.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |
| [create-task](/docs/generated/agents-task-create-create-task) | tests | Task Creation Agent - Mechanical Operations |

---
*Auto-generated from Component Fabric. Card: `tests-unit-create_task_owner_gate.yaml`*
*Last verified: 2026-07-29*
