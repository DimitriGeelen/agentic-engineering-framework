# termlink-circuit-breaker

> Per-target circuit breaker — N failures in window opens the breaker and routes elsewhere; cooldown then half-open. FAILURE_THRESHOLD=3, COOLDOWN=60s hardcoded. T-1642 (Arc A) consults whether these are production-realistic.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-hub/src/circuit_breaker.rs`

**Tags:** `orchestrator-arc`, `resilience`, `circuit-breaker`

## What It Does

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink-router](/docs/generated/cross-repo-termlink-router) | called_by | Hub-side request router. Selects target session for incoming RPC by tag affinity, role, and routing-cache hit. Hardcodes 13 routing-policy constants surfaced by W08 (DEFAULT_MODEL_FALLBACK, PROMOTION_THRESHOLD=5, FAILURE_THRESHOLD=3, COOLDOWN=60s, etc.). Arc A (T-1642) policy-consultation target. |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-circuit-breaker.yaml`*
*Last verified: 2026-05-01*
