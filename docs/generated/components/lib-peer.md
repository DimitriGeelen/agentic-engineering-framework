# peer

> v2 peer-consult subscriber + responder spawn-bridge.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/peer.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_peer_subscribe](/docs/generated/tests-unit-test_peer_subscribe) | called_by | Unit tests for lib/peer.py — v2 peer-consult subscriber + responder spawn. |

---
*Auto-generated from Component Fabric. Card: `lib-peer.yaml`*
*Last verified: 2026-05-13*
