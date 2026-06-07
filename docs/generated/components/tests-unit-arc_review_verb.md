# arc_review_verb

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_review_verb.bats`

## What It Does

T-1962 — fw arc review <slug> CLI verb.
Pins the contract:
- Resolves slug OR arc-NNN form via _arc_normalize_input (mirrors arc_close).
- Emits /arcs/<id>/close URL + arc summary on stdout for in-progress / draft arcs.
- Refuses on terminal states (closed / abandoned) with status text, no URL.
- Unknown arc → non-zero exit with clear message.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_review_verb.yaml`*
*Last verified: 2026-05-21*
