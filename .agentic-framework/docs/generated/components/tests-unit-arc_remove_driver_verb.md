# arc_remove_driver_verb

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_remove_driver_verb.bats`

## What It Does

T-1976 — fw arc remove-driver <slug> "<name>" --rationale "<≥30 chars>" CLI verb.
Pins the contract (symmetric with fw bvp driver --remove):
- Resolves slug OR arc-NNN form via _arc_normalize_input.
- Requires --rationale ≥30 chars (R6).
- Refuses on unknown driver names (no silent no-op).
- §ACD refusal under $CLAUDECODE=1 unless --i-am-human / --from-watchtower.
- On success: removes from scoped_drivers:, appends row to
.context/audits/arc-scoped-driver-removals.jsonl, exit 0.
- arc_dispatch routes 'remove-driver' to arc_remove_driver.
- arc_help lists it under verbs.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_remove_driver_verb.yaml`*
*Last verified: 2026-05-21*
