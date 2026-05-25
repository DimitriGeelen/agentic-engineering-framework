# termlink-governance-subscriber

> T-1066 data plane governance subscriber — watches PTY Output frames asynchronously, emits Governance frames (0x8) on pattern match. Opt-in, non-blocking, bounded queue. Reconsideration finding: run_with_governance has zero non-test callers; subscriber is wired but unused.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-session/src/governance_subscriber.rs`

**Tags:** `orchestrator-arc`, `data-plane`, `subscriber`, `t-1066`, `post-hoc-detection`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink-governance-frame](/docs/generated/cross-repo-termlink-governance-frame) | emits | Data plane Governance frame (frame type 0x8) — informational audit-trail emitted by governance subscribers when pattern matches fire on Output frames. T-1066 wire format. T-1641 reconsideration flagged that frame 0x8 has zero non-test emit callers — T-1648 will pin the protocol so accidental rename breaks loud. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | surfaced_by | TODO: describe what this component does |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | tracked_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-governance-subscriber.yaml`*
*Last verified: 2026-05-01*
