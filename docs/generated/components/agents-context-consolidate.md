# consolidate

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/consolidate.py`

## What It Does

Text similarity (Jaccard on word tokens)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-data](/docs/generated/learnings-data) | calls | Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command. |
| [patterns-data](/docs/generated/patterns-data) | calls | Stores failure, success, and workflow patterns discovered during project work. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `agents-context-consolidate.yaml`*
*Last verified: 2026-09-03*
