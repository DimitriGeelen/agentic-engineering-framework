# bpmn_promote

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/bpmn_promote.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bpmn_to_tasks](/docs/generated/tools-bpmn_to_tasks) | calls | TODO: describe what this component does |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_bpmn_promote](/docs/generated/tests-unit-test_bpmn_promote) | called_by | TODO: describe what this component does |
| [test_bpmn_frozen_v1_pin](/docs/generated/tests-web-test_bpmn_frozen_v1_pin) | called_by | T-2556 AC3 absent-marker half: frozen-v1 byte-pin of the compile→stage→reconcile pipeline on a NO-kind-marker diagram (832's byte-pinned pair-draft-3 fixture). Pins manifest sha256 golden + all-NEW reconcile so the post-ratification kind= consumption legs (compile stamps kind:, promote refuses documentation) provably keep unmarked diagrams byte-identical. Harness-first pattern (T-2579/T-2590). |

---
*Auto-generated from Component Fabric. Card: `tools-bpmn_promote.yaml`*
*Last verified: 2026-07-18*
