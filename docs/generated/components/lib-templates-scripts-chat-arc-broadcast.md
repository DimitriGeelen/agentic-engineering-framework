# chat-arc-broadcast

> Template skill script: cross-hub broadcast helper fanning an agent-chat-arc post to every fleet hub (T-1856, /broadcast-chat)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/chat-arc-broadcast.sh`

## What It Does

T-1856 — Cross-hub broadcast helper for agent-chat-arc.
G-060 mitigation: agent-chat-arc does NOT federate
(see docs/operations/channel-topic-semantics.md). Cross-hub broadcast
requires explicit `channel post --hub <addr>` per hub. This script
wraps that loop with the PL-189 timeout invariant and automatic
metadata.agent_id injection so a single operator command reaches the
fleet with correct attribution.
Sender resolution (priority order):
1. --from <id> flag
2. $TERMLINK_AGENT_ID env

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-chat-arc-broadcast.yaml`*
*Last verified: 2026-09-08*
