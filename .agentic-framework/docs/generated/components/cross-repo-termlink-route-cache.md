# termlink-route-cache

> Persistent routing cache — remembers (request-shape → session) mappings across hub restarts. T-1650 schema-pin candidate. Composite key currently mixes task-type + role + tags; refactor to RoutingKey newtype tracked by T-1636.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-hub/src/route_cache.rs`

**Tags:** `orchestrator-arc`, `routing`, `persistence`, `t-1650-target`

## What It Does

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink-router](/docs/generated/cross-repo-termlink-router) | called_by | Hub-side request router. Selects target session for incoming RPC by tag affinity, role, and routing-cache hit. Hardcodes 13 routing-policy constants surfaced by W08 (DEFAULT_MODEL_FALLBACK, PROMOTION_THRESHOLD=5, FAILURE_THRESHOLD=3, COOLDOWN=60s, etc.). Arc A (T-1642) policy-consultation target. |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-route-cache.yaml`*
*Last verified: 2026-05-01*
