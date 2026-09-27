# corpus_spec

> corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO).

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/corpus_spec.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [designer-pin](/docs/generated/policy-designer-pin) | calls | Pinned Workflow Designer build record (T-2521): the AEF-832 integration contract naming the vendored release (tag, sha, artifact) of the 832-Workflow-designer single-file build. Bumped via pull-at-tag protocol, never edited in place. |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer](/docs/generated/agents-designer-designer) | called_by | fw designer: vendors and serves a pinned Workflow Designer release build via the Watchtower /designer blueprint (832-Workflow-designer is source of truth; T-2521). |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [corpus_lint](/docs/generated/tools-corpus_lint) | uses_by | corpus_lint — per-map + cross-map lint for the designer corpus (T-2604). |
| [test_importer_fidelity](/docs/generated/tests-unit-test_importer_fidelity) | called_by | T-2882 — a CONTENT census of what our BPMN importer does with what it does not consume. |
| [corpus_conformance](/docs/generated/tools-corpus_conformance) | uses_by | Map-conformance rail — corpus map assertions vs the enforced state machine. |
| [corpus_explain](/docs/generated/tools-corpus_explain) | uses_by | T-2622: agent retrieval seam — corpus maps readable without a browser. |
| [corpus_overlay](/docs/generated/tools-corpus_overlay) | uses_by | T-2629 (T-2620 GO, Slice A): live task-state projection onto map carrier uids. |

---
*Auto-generated from Component Fabric. Card: `tools-corpus_spec.yaml`*
*Last verified: 2026-07-22*
