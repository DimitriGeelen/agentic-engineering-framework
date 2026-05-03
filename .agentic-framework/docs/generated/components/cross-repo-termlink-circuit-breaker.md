# termlink-circuit-breaker

> Per-target circuit breaker — N failures in window opens the breaker and routes elsewhere; cooldown then half-open. FAILURE_THRESHOLD=3, COOLDOWN=60s hardcoded. T-1642 (Arc A) consults whether these are production-realistic.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-hub/src/circuit_breaker.rs`

**Tags:** `orchestrator-arc`, `resilience`, `circuit-breaker`

## What It Does

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `cross-repo:termlink/crates/termlink-hub/src/router.rs` | called_by |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-circuit-breaker.yaml`*
*Last verified: 2026-05-01*
