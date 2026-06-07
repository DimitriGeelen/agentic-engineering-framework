# termlink-bypass

> Bypass registry — N consecutive successful direct-routes promote a (caller, target) pair to bypass-cache (skip router). PROMOTION_THRESHOLD=5 hardcoded; T-1642 (Arc A) consults the human on whether 5 is the right bar.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-hub/src/bypass.rs`

**Tags:** `orchestrator-arc`, `routing`, `bypass`, `promotion`

## What It Does

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink-router](/docs/generated/cross-repo-termlink-router) | called_by | Hub-side request router. Selects target session for incoming RPC by tag affinity, role, and routing-cache hit. Hardcodes 13 routing-policy constants surfaced by W08 (DEFAULT_MODEL_FALLBACK, PROMOTION_THRESHOLD=5, FAILURE_THRESHOLD=3, COOLDOWN=60s, etc.). Arc A (T-1642) policy-consultation target. |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-bypass.yaml`*
*Last verified: 2026-05-01*
