# agent-listeners-fleet

> Template skill script: cross-hub agent-presence discovery aggregating listener heartbeats across the fleet (T-1837, /peers)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/agent-listeners-fleet.sh`

## What It Does

T-1837 — Cross-hub agent-presence discovery.
`agent-listeners.sh` reads ONE hub. G-060: channel topics (including
agent-presence) are hub-local; there is no inter-hub federation
primitive. This verb walks every profile in `~/.termlink/hubs.toml`,
calls the single-hub verb per profile in parallel, and merges the
results by `agent_id` with a deterministic preference rule:
LIVE > STALE > OFFLINE
(status tie) → most-recent last_seen_ts wins
Each surviving row carries `hub` = the profile address that saw the
winning heartbeat last (so the caller can route a doorbell ring to

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-agent-listeners-fleet.yaml`*
*Last verified: 2026-09-08*
