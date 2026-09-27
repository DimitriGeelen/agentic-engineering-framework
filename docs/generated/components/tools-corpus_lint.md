# corpus_lint

> corpus_lint — per-map + cross-map lint for the designer corpus (T-2604).

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/corpus_lint.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_spec](/docs/generated/tools-corpus_spec) | uses | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |
| [designer-pin](/docs/generated/policy-designer-pin) | calls | Pinned Workflow Designer build record (T-2521): the AEF-832 integration contract naming the vendored release (tag, sha, artifact) of the 832-Workflow-designer single-file build. Bumped via pull-at-tag protocol, never edited in place. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit_corpus_lint_findings](/docs/generated/tests-unit-audit_corpus_lint_findings) | called_by | T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit. |
| [audit_corpus_lint_findings](/docs/generated/tests-unit-audit_corpus_lint_findings) | tests_by | T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tools-corpus_lint.yaml`*
*Last verified: 2026-07-22*
