# audit_seed_corpus_refs

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_seed_corpus_refs.bats`

## What It Does

T-2980 (arc-017, onboarding-curriculum): seed → corpus-map reference resolution.
The onboarding seeds route to corpus maps instead of embedding their content
(arc-017's design principle). Each `## For the Operator` section ends with
`fw corpus explain <id>` — a command the framework tells a first-time operator
to run. If that id stops resolving, they get a tool error in their first hour.
FAIL rather than WARN, unlike the anchor_task sibling in
audit_anchor_task_existence.bats: the seeds are copied into every project by
`fw init`, so a dangling reference ships to new installs and is discovered one
confused operator at a time. Deterministic, operator-facing, one-line fix.
The last test is the one that matters most over time: it checks the audit's

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_seed_corpus_refs.yaml`*
*Last verified: 2026-08-14*
