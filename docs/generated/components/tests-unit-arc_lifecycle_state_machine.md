# arc_lifecycle_state_machine

> T-1852 (T-NEW-5a): arc lifecycle state machine.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/arc_lifecycle_state_machine.bats`

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
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [arc](/docs/generated/lib-arc) | tests | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_lifecycle_state_machine.yaml`*
*Last verified: 2026-05-16*
