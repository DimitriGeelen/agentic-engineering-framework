# learnings

> TODO: describe what this component does

**Type:** data | **Subsystem:** unknown | **Location:** `.context/project/learnings.yaml`

## What It Does

Project Learnings - Knowledge gained during development
Added via: fw context add-learning "description" --task T-XXX

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [add_learning_id_allocator](/docs/generated/tests-unit-add_learning_id_allocator) | read_by | Regression test — add-learning ID allocator handles BOTH legacy indented format ('  id: L-XXX') and new dash-prefix format ('- id: L-XXX'). Pre-fix grep for '^- id: L-' missed 234 legacy entries, causing new IDs to collide with historical ones. |

## Related

### Tasks
- T-937: Commit pending handover checkpoints

---
*Auto-generated from Component Fabric. Card: `context-project-learnings.yaml`*
*Last verified: 2026-09-04*
