# agent-conversation-list

> Template skill script: enumerate doorbell+mail conversation threads on a topic (T-1827, /conversations)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/agent-conversation-list.sh`

## What It Does

T-1827 — enumerate conversations on a topic.
Sibling of agent-conversation-status.sh (T-1826). Where status answers
"how is cid-X doing?", list answers "what cids are alive on this topic?"
Closes the orchestration gap for autonomous a2a: an agent supervising N
concurrent doorbell+mail threads can call this verb to enumerate its own
active set (and any abandoned/stalled ones it should clean up).
Read-only. Composes `channel subscribe --json` + jq. Envelopes without
metadata.conversation_id are skipped by default (focus on doorbell+mail
pattern) but can be aggregated under a sentinel `(no-cid)` row via
--include-no-cid for cross-pattern surveys.

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-agent-conversation-list.yaml`*
*Last verified: 2026-09-08*
