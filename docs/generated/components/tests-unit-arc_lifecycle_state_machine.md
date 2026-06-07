# arc_lifecycle_state_machine

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_lifecycle_state_machine.bats`

## What It Does

T-1852 (T-NEW-5a): arc lifecycle state machine.
Four allowed states (ARC_STATES): draft, in-progress, closed, abandoned.
Transitions:
arc_create  → status: draft (T-1852 changed default; pre-T-1852 arcs
untouched, remain in-progress per D3)
arc_start   → draft → in-progress
arc_close   → in-progress → closed
arc_abandon → draft|in-progress → abandoned (T-1854, not in this slice)
Refusals exit non-zero with actionable error citing the allowed transitions.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_lifecycle_state_machine.yaml`*
*Last verified: 2026-05-16*
