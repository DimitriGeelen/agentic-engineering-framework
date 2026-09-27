# message_router

> T-3046 — static ``msg_type`` router for recovered hub messages (slice 1 of T-3044).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/message_router.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [keylock-py](/docs/generated/lib-keylock-py) | uses | Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t3046_message_router](/docs/generated/tests-unit-t3046_message_router) | called_by | T-3046 — static msg_type router for recovered hub messages (slice 1 of T-3044). |
| [t3046_message_router](/docs/generated/tests-unit-t3046_message_router) | tests_by | T-3046 — static msg_type router for recovered hub messages (slice 1 of T-3044). |

---
*Auto-generated from Component Fabric. Card: `lib-message_router.yaml`*
*Last verified: 2026-08-16*
