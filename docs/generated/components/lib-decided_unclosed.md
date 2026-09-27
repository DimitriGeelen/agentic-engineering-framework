# decided_unclosed

> T-3175: inceptions that are DECIDED but still open — the queue nobody showed.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/decided_unclosed.py`

## What It Does

A decision that CONCLUDES an inception. DEFER deliberately absent — see module
docstring; it is a park, not a pending closure.

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_inception_close_card](/docs/generated/tests-unit-test_inception_close_card) | called_by | T-3180: a decided inception must have a way to close it. |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [inception](/docs/generated/web-blueprints-inception) | called_by | Blueprint 'inception' — routes: /inception |

---
*Auto-generated from Component Fabric. Card: `lib-decided_unclosed.yaml`*
*Last verified: 2026-09-03*
