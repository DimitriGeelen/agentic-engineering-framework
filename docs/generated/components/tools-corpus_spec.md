# corpus_spec

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/corpus_spec.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer](/docs/generated/agents-designer-designer) | called_by | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [corpus_lint](/docs/generated/tools-corpus_lint) | uses_by | TODO: describe what this component does |
| [test_importer_fidelity](/docs/generated/tests-unit-test_importer_fidelity) | called_by | TODO: describe what this component does |
| [corpus_conformance](/docs/generated/tools-corpus_conformance) | uses_by | TODO: describe what this component does |
| [corpus_explain](/docs/generated/tools-corpus_explain) | uses_by | TODO: describe what this component does |
| [corpus_overlay](/docs/generated/tools-corpus_overlay) | uses_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tools-corpus_spec.yaml`*
*Last verified: 2026-07-22*
