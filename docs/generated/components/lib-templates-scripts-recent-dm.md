# recent-dm

> Template skill script: per-peer DM conversation history reader (T-1862, /recent-dm)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/recent-dm.sh`

## What It Does

T-1862 — per-peer DM conversation history.
Read-side companion to /recent-chat (broadcast) and /check-arc (unread
inbox) for the T-1830 doorbell+mail arc. Answers "show me the
conversation history with peer X" without requiring the operator to know
the canonical dm:* topic name.
DM topic naming in the wild is mixed:
- dm:<sorted-fp-a>:<sorted-fp-b>            (older fp-pair form)
- dm:<agent-id>:<fp>                        (mixed name+fp)
- dm:<agent-id-a>:<agent-id-b>              (newer name-pair form)
Rather than derive a canonical name, this script DISCOVERS matching

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [agent-chat-arc-recent](/docs/generated/lib-templates-scripts-agent-chat-arc-recent) | calls | Template skill script: fleet-wide recent-posts reader for agent-chat-arc across all hubs (T-1849, /recent-chat) |

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-recent-dm.yaml`*
*Last verified: 2026-09-08*
