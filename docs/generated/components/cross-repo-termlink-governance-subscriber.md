# termlink-governance-subscriber

> T-1066 data plane governance subscriber — watches PTY Output frames asynchronously, emits Governance frames (0x8) on pattern match. Opt-in, non-blocking, bounded queue. Reconsideration finding: run_with_governance has zero non-test callers; subscriber is wired but unused.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-session/src/governance_subscriber.rs`

**Tags:** `orchestrator-arc`, `data-plane`, `subscriber`, `t-1066`, `post-hoc-detection`

## What It Does

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `cross-repo:termlink/crates/termlink-protocol/src/governance.rs` | emits |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/orchestrator.py` | surfaced_by |
| `agents/audit/orchestrator-mcp-scan.sh` | tracked_by |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-governance-subscriber.yaml`*
*Last verified: 2026-05-01*
