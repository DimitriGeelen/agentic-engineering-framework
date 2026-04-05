# decisions

> Decision log recording architectural and process decisions with rationale and rejected alternatives.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/decisions.yaml`

**Tags:** `context`, `project-memory`

## What It Does

Project Decisions - Architectural choices with rationale
Added via: fw context add-decision "description" --task T-XXX --rationale "why"

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `agents/context/context.sh` | read_by |
| `agents/audit/audit.sh` | read_by |

## Related

### Tasks
- T-677: Fix fw init hook merge — pre-existing settings.json blocks framework hooks

---
*Auto-generated from Component Fabric. Card: `context-project-decisions.yaml`*
*Last verified: 2026-03-04*
