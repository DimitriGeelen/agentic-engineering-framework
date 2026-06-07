# termlink-governance-frame

> Data plane Governance frame (frame type 0x8) — informational audit-trail emitted by governance subscribers when pattern matches fire on Output frames. T-1066 wire format. T-1641 reconsideration flagged that frame 0x8 has zero non-test emit callers — T-1648 will pin the protocol so accidental rename breaks loud.

**Type:** source | **Subsystem:** orchestrator-arc | **Location:** `/opt/termlink/crates/termlink-protocol/src/governance.rs`

**Tags:** `orchestrator-arc`, `protocol`, `governance-frame`, `frame-0x8`, `t-1648-target`

## What It Does

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink-governance-subscriber](/docs/generated/cross-repo-termlink-governance-subscriber) | emitted_by | T-1066 data plane governance subscriber — watches PTY Output frames asynchronously, emits Governance frames (0x8) on pattern match. Opt-in, non-blocking, bounded queue. Reconsideration finding: run_with_governance has zero non-test callers; subscriber is wired but unused. |
| [termlink-governance-subscriber](/docs/generated/cross-repo-termlink-governance-subscriber) | emits_by | T-1066 data plane governance subscriber — watches PTY Output frames asynchronously, emits Governance frames (0x8) on pattern match. Opt-in, non-blocking, bounded queue. Reconsideration finding: run_with_governance has zero non-test callers; subscriber is wired but unused. |

---
*Auto-generated from Component Fabric. Card: `cross-repo-termlink-governance-frame.yaml`*
*Last verified: 2026-05-01*
