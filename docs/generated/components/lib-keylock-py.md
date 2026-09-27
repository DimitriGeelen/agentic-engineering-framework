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
| [spawn](/docs/generated/lib-spawn) | calls | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [spawn](/docs/generated/lib-spawn) | called_by | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |
| [resolver](/docs/generated/lib-resolver) | called_by | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [test_spawn](/docs/generated/tests-unit-test_spawn) | tests_by | T-1773: Unit tests for lib/spawn.py. |
| [message_router](/docs/generated/lib-message_router) | uses_by | T-3046 — static ``msg_type`` router for recovered hub messages (slice 1 of T-3044). |
| [resolver](/docs/generated/lib-resolver) | uses_by | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [spawn](/docs/generated/lib-spawn) | uses_by | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |

---
*Auto-generated from Component Fabric. Card: `lib-keylock-py.yaml`*
*Last verified: 2026-08-16*
