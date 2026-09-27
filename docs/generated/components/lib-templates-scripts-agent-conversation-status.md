# agent-conversation-status

> Template skill script: read-only state diagnostic for a single conversation_id thread (T-1826)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/agent-conversation-status.sh`

## What It Does

T-1826 — conversation_id state diagnostic.
Read-only summary of a single conversation thread identified by
`metadata.conversation_id`. Closes the observability gap in the
doorbell+mail loop (T-1800/T-1804/T-1805): agent-send.sh polls
receipts internally and exits status-only; agent-respond.sh posts
receipts; nothing external can answer "where is cid-X right now?"
for a third observer (operator or orchestrator agent supervising
concurrent autonomous a2a threads).
Composes existing first-class primitives:
- `channel subscribe --conversation-id <cid> --json`  (cli.rs:2319)

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-agent-conversation-status.yaml`*
*Last verified: 2026-09-08*
