# arc_set_scoped_weight

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_set_scoped_weight.bats`

## What It Does

T-1977 — fw arc set-scoped-weight <slug> "<name>" --weight N --rationale "<≥30 chars>" CLI verb.
Pins the contract (mirrors T-1929 /bvp weight sliders at arc scope):
- Requires --weight (1-6, M2 cap) and --rationale (≥30 chars, R6).
- Refuses on unknown driver names (no silent no-op).
- §ACD refusal under $CLAUDECODE=1 unless --i-am-human / --from-watchtower.
- On success: mutates scoped_drivers[].weight in place, appends audit row
to .context/audits/arc-scoped-weight-changes.jsonl, exit 0.
- arc_dispatch routes 'set-scoped-weight' to arc_set_scoped_weight.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_set_scoped_weight.yaml`*
*Last verified: 2026-05-21*
