# keylock-py

> Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042.

**Type:** library | **Subsystem:** framework-core | **Location:** `lib/keylock.py`

**Tags:** `concurrency`, `locking`

## What It Does

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [spawn](/docs/generated/lib-spawn) | called_by | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | called_by | TODO: describe what this component does |
| [test_spawn](/docs/generated/tests-unit-test_spawn) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-keylock-py.yaml`*
*Last verified: 2026-08-16*
