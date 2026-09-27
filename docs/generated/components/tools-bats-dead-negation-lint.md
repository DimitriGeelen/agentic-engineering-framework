# bats-dead-negation-lint

> T-3138: find bats assertions that cannot fail.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/bats-dead-negation-lint.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bats-dead-negation](/docs/generated/tests-lint-bats-dead-negation) | tests_by | T-3138 — no bats assertion in this repo may be one that cannot fail. |
| [bats-dead-negation-mutants](/docs/generated/tools-bats-dead-negation-mutants) | called_by | T-3138 AC6: mutate the dead-negation lint, confirm its own suite goes red. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tools-bats-dead-negation-lint.yaml`*
*Last verified: 2026-08-25*
