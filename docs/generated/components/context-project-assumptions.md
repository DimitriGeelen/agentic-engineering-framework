# assumptions

> Project assumption register. Tracks assumptions made during inception and build tasks, with validation status and evidence.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/assumptions.yaml`

**Tags:** `context`, `project-memory`

## What It Does

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | read_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [assumption](/docs/generated/lib-assumption) | read_by | fw assumption - Assumption tracking |
| [inception](/docs/generated/web-blueprints-inception) | called_by | Blueprint 'inception' — routes: /inception |

## Related

### Tasks
- T-993: Batch operation governance — prevent agent batch-modifying task horizons without per-task justification

---
*Auto-generated from Component Fabric. Card: `context-project-assumptions.yaml`*
*Last verified: 2026-03-04*
