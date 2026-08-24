# keylock-py

> Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042.

**Type:** library | **Subsystem:** framework-core | **Location:** `lib/keylock.py`

**Tags:** `concurrency`, `locking`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [keylock](/docs/generated/lib-keylock) | calls | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [spawn](/docs/generated/lib-spawn) | calls | TODO: describe what this component does |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [spawn](/docs/generated/lib-spawn) | called_by | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | called_by | TODO: describe what this component does |
| [test_spawn](/docs/generated/tests-unit-test_spawn) | tests_by | TODO: describe what this component does |
| [message_router](/docs/generated/lib-message_router) | uses_by | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | uses_by | TODO: describe what this component does |
| [spawn](/docs/generated/lib-spawn) | uses_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-keylock-py.yaml`*
*Last verified: 2026-08-16*
