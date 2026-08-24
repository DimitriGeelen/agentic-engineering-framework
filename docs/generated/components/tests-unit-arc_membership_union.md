# arc_membership_union

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_membership_union.bats`

## What It Does

T-1874: _arc_tasks_for unions arc_id frontmatter + legacy arc:<slug> tag.
Verifies the post-T-1850 migration blindness fix: fw arc show / fw arc list
constituent-task counts must include tasks whose membership is declared via
the canonical `arc_id:` frontmatter (T-1849), not only legacy `arc:<slug>`
tags. Both forms coexist during the transition; this test pins the union
semantics.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_membership_union.yaml`*
*Last verified: 2026-05-16*
