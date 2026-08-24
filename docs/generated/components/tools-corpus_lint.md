# corpus_lint

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/corpus_lint.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_spec](/docs/generated/tools-corpus_spec) | uses | TODO: describe what this component does |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit_corpus_lint_findings](/docs/generated/tests-unit-audit_corpus_lint_findings) | called_by | TODO: describe what this component does |
| [audit_corpus_lint_findings](/docs/generated/tests-unit-audit_corpus_lint_findings) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tools-corpus_lint.yaml`*
*Last verified: 2026-07-22*
