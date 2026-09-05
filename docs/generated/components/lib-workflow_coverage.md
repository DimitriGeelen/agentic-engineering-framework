# workflow_coverage

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/workflow_coverage.py`

## What It Does

T-3273: worker_kinds that are valid (lib.resolver.VALID_WORKER_KINDS) but
deliberately absent from lib.spawn._DISPATCHERS — they never spawn a worker
at all, so "not in _DISPATCHERS" is not the runtime-trap this checker exists
to catch. "ollama-direct" (T-1719 A3) answers synchronously in fw ask's own
process; see .context/project/workflows/ask.yaml's header comment and
lib/resolver.py:95. Sibling exemption to the `inline:` flag, which excludes
non-resolver-driven workflows from the staleness check the same way.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [spawn](/docs/generated/lib-spawn) | uses | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | uses | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | calls | TODO: describe what this component does |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_workflow_coverage](/docs/generated/tests-unit-test_workflow_coverage) | called_by | TODO: describe what this component does |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `lib-workflow_coverage.yaml`*
*Last verified: 2026-05-12*
