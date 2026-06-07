# termlink-router

> Hub-side request router. Selects target session for incoming RPC by tag affinity, role, and routing-cache hit. Hardcodes 13 routing-policy constants surfaced by W08 (DEFAULT_MODEL_FALLBACK, PROMOTION_THRESHOLD=5, FAILURE_THRESHOLD=3, COOLDOWN=60s, etc.). Arc A (T-1642) policy-consultation target.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-hub/src/router.rs`

**Tags:** `orchestrator-arc`, `routing`, `t-1064-target`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink-route-cache](/docs/generated/cross-repo-termlink-route-cache) | calls | Persistent routing cache — remembers (request-shape → session) mappings across hub restarts. T-1650 schema-pin candidate. Composite key currently mixes task-type + role + tags; refactor to RoutingKey newtype tracked by T-1636. |
| [termlink-circuit-breaker](/docs/generated/cross-repo-termlink-circuit-breaker) | calls | Per-target circuit breaker — N failures in window opens the breaker and routes elsewhere; cooldown then half-open. FAILURE_THRESHOLD=3, COOLDOWN=60s hardcoded. T-1642 (Arc A) consults whether these are production-realistic. |
| [termlink-bypass](/docs/generated/cross-repo-termlink-bypass) | calls | Bypass registry — N consecutive successful direct-routes promote a (caller, target) pair to bypass-cache (skip router). PROMOTION_THRESHOLD=5 hardcoded; T-1642 (Arc A) consults the human on whether 5 is the right bar. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | surfaced_by | TODO: describe what this component does |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | audited_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-router.yaml`*
*Last verified: 2026-05-01*
