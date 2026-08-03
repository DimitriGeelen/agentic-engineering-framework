# handover_checkpoint_push

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/handover_checkpoint_push.bats`

## What It Does

T-2588 — `handover.sh --checkpoint` must push the checkpoint commit, not
just commit it locally. Checkpoint commits accumulate mid-session; if the
session dies before a later normal handover, or the budget gate blocks a
subsequent push (T-2587), the checkpoint commit — the exact state a
checkpoint exists to protect — was stranded unpushed.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [handover](/docs/generated/agents-handover-handover) | tests | Handover Agent - Mechanical Operations |

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_checkpoint_push.yaml`*
*Last verified: 2026-07-21*
