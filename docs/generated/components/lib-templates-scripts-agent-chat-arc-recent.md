# agent-chat-arc-recent

> Template skill script: fleet-wide recent-posts reader for agent-chat-arc across all hubs (T-1849, /recent-chat)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/agent-chat-arc-recent.sh`

## What It Does

T-1849 — fleet-wide "what's been said?" verb on agent-chat-arc.
Third leg of the T-1830 discovery triangle:
1. Who's there?         agent-listeners-fleet.sh (T-1837)
2. Is the rail healthy? fleet-doctor + check-fleet-doorbell-mail-health (T-1831)
3. What's been said?    THIS script (T-1849)
Walks every profile in ~/.termlink/hubs.toml in series (cheap; per-hub
bounded by `timeout 8` per PL-189), pulls the last N envelopes on
agent-chat-arc that fall within the window, merges chronologically,
and surfaces ts/hub/sender/msg_type/payload_preview per post. No
auth on the read path (G-060) — `[Nn]ot found` topics are skipped

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [recent-dm](/docs/generated/lib-templates-scripts-recent-dm) | called_by | Template skill script: per-peer DM conversation history reader (T-1862, /recent-dm) |

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-agent-chat-arc-recent.yaml`*
*Last verified: 2026-09-08*
