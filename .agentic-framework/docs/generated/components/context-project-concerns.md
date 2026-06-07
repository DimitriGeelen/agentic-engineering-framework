# concerns

> Unified concerns register (gaps + risks) tracking spec-reality gaps, identified risks, severity, mitigation plans, and resolution status. Consolidated from gaps.yaml, issues.yaml, and risks.yaml by T-397.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/concerns.yaml`

**Tags:** `context`, `project-memory`, `governance`

## What It Does

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [risks](/docs/generated/web-blueprints-risks) | read_by | Flask blueprint 'risks' serving routes: /risks |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | read_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [handover](/docs/generated/agents-handover-handover) | read_by | Handover Agent - Mechanical Operations |

---
*Auto-generated from Component Fabric. Card: `context-project-concerns.yaml`*
*Last verified: 2026-03-10*
