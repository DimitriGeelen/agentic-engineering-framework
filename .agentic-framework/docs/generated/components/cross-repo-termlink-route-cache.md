# termlink-route-cache

> Persistent routing cache — remembers (request-shape → session) mappings across hub restarts. T-1650 schema-pin candidate. Composite key currently mixes task-type + role + tags; refactor to RoutingKey newtype tracked by T-1636.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-hub/src/route_cache.rs`

**Tags:** `orchestrator-arc`, `routing`, `persistence`, `t-1650-target`

## What It Does

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `cross-repo:termlink/crates/termlink-hub/src/router.rs` | called_by |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-route-cache.yaml`*
*Last verified: 2026-05-01*
