# memory-recall

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/memory-recall.py`

## What It Does

Colors

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [learnings-data](/docs/generated/learnings-data) | calls | Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command. |
| [patterns-data](/docs/generated/patterns-data) | calls | Stores failure, success, and workflow patterns discovered during project work. |
| [decisions](/docs/generated/context-project-decisions) | calls | Decision log recording architectural and process decisions with rationale and rejected alternatives. |
| [embeddings](/docs/generated/web-embeddings) | uses | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [focus](/docs/generated/agents-context-lib-focus) | called_by | Context Agent - focus command |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t3056_recall_open_tasks](/docs/generated/tests-unit-t3056_recall_open_tasks) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-memory-recall.yaml`*
*Last verified: 2026-09-03*
