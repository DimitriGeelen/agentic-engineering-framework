# termlink-router

> Hub-side request router. Selects target session for incoming RPC by tag affinity, role, and routing-cache hit. Hardcodes 13 routing-policy constants surfaced by W08 (DEFAULT_MODEL_FALLBACK, PROMOTION_THRESHOLD=5, FAILURE_THRESHOLD=3, COOLDOWN=60s, etc.). Arc A (T-1642) policy-consultation target.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-hub/src/router.rs`

**Tags:** `orchestrator-arc`, `routing`, `t-1064-target`

## What It Does

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `cross-repo:termlink/crates/termlink-hub/src/route_cache.rs` | calls |
| `cross-repo:termlink/crates/termlink-hub/src/circuit_breaker.rs` | calls |
| `cross-repo:termlink/crates/termlink-hub/src/bypass.rs` | calls |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/orchestrator.py` | surfaced_by |
| `agents/audit/orchestrator-mcp-scan.sh` | audited_by |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-router.yaml`*
*Last verified: 2026-05-01*
