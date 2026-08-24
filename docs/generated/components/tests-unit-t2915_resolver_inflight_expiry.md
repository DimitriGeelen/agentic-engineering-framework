# t2915_resolver_inflight_expiry

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2915_resolver_inflight_expiry.bats`

## What It Does

T-2915: the resolver's in-flight latch never expired — a dispatch row with
no terminal_event excluded its task from the loop forever, because
`_inflight_task_ids()` had no age bound. Nine tasks sat latched for five
weeks with no distinguishing signal in `dispatched 0`. These tests pin the
CLI-level surfaces: `fw resolver latched` (AC5, stale-latch visibility) and
`fw resolver loop --json` naming its own silence (AC3).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | calls | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2915_resolver_inflight_expiry.yaml`*
*Last verified: 2026-08-11*
