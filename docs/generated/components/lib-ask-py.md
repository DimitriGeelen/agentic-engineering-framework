# ask-py

> Python implementation of fw ask subcommand (sibling of lib/ask.sh)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/ask.py`

**Tags:** `lib`, `fw-subcommand`

## What It Does

Add project root to path so web modules are importable

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [focus](/docs/generated/agents-context-lib-focus) | called_by | Context Agent - focus command |
| [diagnose](/docs/generated/agents-healing-lib-diagnose) | called_by | Healing Agent - diagnose command |
| [ask](/docs/generated/lib-ask) | called_by | fw ask subcommand. Provides interactive question/answer prompts for framework configuration and user input collection. |

---
*Auto-generated from Component Fabric. Card: `lib-ask-py.yaml`*
*Last verified: 2026-05-06*
