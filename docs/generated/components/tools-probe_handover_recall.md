# probe_handover_recall

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/probe_handover_recall.py`

## What It Does

Queries chosen to span the kinds of thing the corpus is actually asked, and
written down so this is repeatable rather than a one-off. Deliberately mixed:
some are the "what happened in a past session" shape a handover is uniquely

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

---
*Auto-generated from Component Fabric. Card: `tools-probe_handover_recall.yaml`*
*Last verified: 2026-08-16*
