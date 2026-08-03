# designer_sync_from_tag

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/designer_sync_from_tag.bats`

## What It Does

T-2616: fw designer sync --from-tag — pull-at-tag intake contract (T-247/D-335).
The intake fetches artifact + MANIFEST.yaml AT an annotated tag from the pin's
read-only `source_origin` and refuses install unless the independently computed
sha256 matches BOTH the MANIFEST at the same tag AND the pin. These tests use a
LOCAL fixture origin (throwaway git repo + annotated tag) — zero network.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer](/docs/generated/agents-designer-designer) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-designer_sync_from_tag.yaml`*
*Last verified: 2026-07-23*
