# add_learning_id_allocator

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/add_learning_id_allocator.bats`

## What It Does

T-1369: add-learning ID allocator handles BOTH legacy indented-format
(`  id: L-XXX`, where `- application:` opens the list item) and new
dash-prefix format (`- id: L-XXX`).
Before the fix, grep for `^- id: L-` missed 234 legacy entries, so every
new add-learning call issued an ID that collided with historical IDs.

---
*Auto-generated from Component Fabric. Card: `tests-unit-add_learning_id_allocator.yaml`*
*Last verified: 2026-04-20*
