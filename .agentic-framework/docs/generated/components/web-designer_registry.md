# designer_registry

> TODO: describe what this component does

**Type:** script | **Subsystem:** watchtower | **Location:** `web/designer_registry.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer_api](/docs/generated/web-blueprints-designer_api) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_designer_registry_claim](/docs/generated/tests-web-test_designer_registry_claim) | called_by | TODO: describe what this component does |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | called_by | TODO: describe what this component does |
| [designer](/docs/generated/web-blueprints-designer) | called_by | TODO: describe what this component does |
| [designer_api](/docs/generated/web-blueprints-designer_api) | called_by | TODO: describe what this component does |
| [test_s4_exemplar_intake](/docs/generated/tests-web-test_s4_exemplar_intake) | called_by | Drop-point intake harness for 832's future PICKER-authored S4 exemplar (their T-228): skips until tests/fixtures/832/s4-exemplar.{bpmn,sha256} are delivered, then flips to full asserts — sha pin verify, editor-authorship fingerprint (workflowMeta uuid present, no linkEventThrow/Catch host tags, links ride extensionElements on intermediate throw/catch), Pass-5 three-leg classification vs the live corpus, and per-leg registry outcome via sync_project_refs on a meta-clone store. Synthetic editor-dialect test runs green pre-delivery (T-2593; pattern sibling of test_pair_draft3_intake). |

---
*Auto-generated from Component Fabric. Card: `web-designer_registry.yaml`*
*Last verified: 2026-07-20*
