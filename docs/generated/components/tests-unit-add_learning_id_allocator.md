# add_learning_id_allocator

> Regression test — add-learning ID allocator handles BOTH legacy indented format ('  id: L-XXX') and new dash-prefix format ('- id: L-XXX'). Pre-fix grep for '^- id: L-' missed 234 legacy entries, causing new IDs to collide with historical ones.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/add_learning_id_allocator.bats`

**Tags:** `test`, `learning`, `id-allocator`, `T-1369`

## What It Does

T-1369: add-learning ID allocator handles BOTH legacy indented-format
(`  id: L-XXX`, where `- application:` opens the list item) and new
dash-prefix format (`- id: L-XXX`).
Before the fix, grep for `^- id: L-` missed 234 legacy entries, so every
new add-learning call issued an ID that collided with historical IDs.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/context/lib/learning.sh` | calls |
| `.context/project/learnings.yaml` | reads |

---
*Auto-generated from Component Fabric. Card: `tests-unit-add_learning_id_allocator.yaml`*
*Last verified: 2026-04-24*
