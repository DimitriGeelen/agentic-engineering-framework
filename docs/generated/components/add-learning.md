# add-learning

> Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section.

**Type:** script | **Subsystem:** learnings-pipeline | **Location:** `agents/context/lib/learning.sh`

**Tags:** `learning`, `context`, `memory`, `yaml-writer`

## What It Does

Context Agent - add-learning command
Add a learning to project memory

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `F-001` | writes |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `C-001` | calls |
| `C-001` | called_by |

## Related

### Tasks
- T-206: Fix add-learning YAML indentation + ID bug
- T-348: Fix update-task.sh sed failing on macOS BSD sed

---
*Auto-generated from Component Fabric. Card: `add-learning.yaml`*
*Last verified: 2026-02-20*
