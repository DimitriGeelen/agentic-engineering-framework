# agent-identity

> Template skill script: shared agent_id resolver sourced by agent-send/agent-respond so all agent-chat producers agree on identity (T-3286)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/agent-identity.sh`

## What It Does

T-3286 — shared agent_id resolver for agent-chat producers.
Sourced (not executed) by agent-send.sh and agent-respond.sh so all three
producer sites (turn post, receipt post, reply post) stamp
`metadata.agent_id` from ONE resolution chain. Grain: INSTANCE identity
(T-3287 D1, operator-ratified 2026-09-06) — two distinct agent-instances
must NEVER collapse to one correspondent.
Resolution chain, most-specific first:
1. FW_AGENT_ID          — explicit per-process env override. Set by the
session itself for ITS OWN name (e.g. to match
its /be-reachable logical id).

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-agent-identity.yaml`*
*Last verified: 2026-09-08*
