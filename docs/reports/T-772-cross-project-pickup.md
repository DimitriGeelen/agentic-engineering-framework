# T-772: Cross-Project Pickup Channel — Research

## TermLink Primitives Available

Queried `termlink 0.9.33` for relevant capabilities. Four primitives map directly to the pickup use case:

### 1. `termlink agent ask` (best fit for structured intake)
- Typed request/response: `--action "pickup.submit" --params '{"type":"bug","summary":"..."}'`
- Built-in timeout, JSON output, sender identity
- Requires target session to be running `termlink agent listen`
- **Pro:** Structured, typed, bidirectional (can return acknowledgement)
- **Con:** Requires active listener session on framework side

### 2. `termlink remote push` (best fit for async delivery)
- Push file/message to remote session inbox: `termlink remote push hub-addr framework-session pickup.json`
- PTY notification on arrival
- Works cross-machine via hub
- **Pro:** Async (framework agent doesn't need to be listening), file-based (persistent)
- **Con:** No structured reply, requires hub profile setup

### 3. `termlink event emit-to` (best fit for fire-and-forget)
- Push event to target session via hub routing
- Topic-based: `--topic "pickup.bug" --payload '{"summary":"..."}'`
- **Pro:** Lightweight, topic-based routing, no session management
- **Con:** Events are ephemeral — lost if no listener

### 4. `termlink request` (best fit for request/reply workflows)
- Send request event, wait for reply on a reply-topic
- `--topic "pickup.submit" --reply-topic "pickup.ack" --payload '{...}'`
- **Pro:** Full request/reply cycle, topic-based
- **Con:** Requires both sides to be running

## Recommended Architecture

```
Consumer Project Agent                    Framework Agent
        |                                       |
        |  termlink remote push                  |
        |  → pickup.json to inbox                |
        |  (async, survives offline)             |
        |                                        |
        |  OR termlink agent ask                 |
        |  → action: pickup.submit               |
        |  ← response: {ack, task_id}           |
        |  (sync, structured, needs listener)   |
```

**Primary channel:** `termlink remote push` (async, survives framework offline)
**Upgrade path:** `termlink agent ask` when both sides are running (richer interaction)

## Pickup Schema (draft)

```yaml
# pickup-envelope.yaml
version: 1
type: bug-report | learning | feature-proposal | pattern
source:
  project: "consumer-project-name"
  task_id: "T-123"          # originating task (optional)
  agent: "claude-code"      # sending agent
  timestamp: "2026-03-30T12:00:00Z"
payload:
  summary: "One-line description"
  detail: "Multi-line explanation"
  evidence: "File path or inline data"
  priority: low | medium | high
  tags: [tag1, tag2]
```

## Intake Governance Model

1. **Pickup arrives** (via `remote push` to inbox or `agent ask`)
2. **Framework agent reads** pickup from inbox (polling or listener)
3. **Auto-create inception task** — NEVER a build task (T-469 lesson)
4. **Dedup check** — search existing tasks for matching summary/tags
5. **Notify human** — `fw notify` with pickup summary
6. **Human reviews** at `/approvals` — go/no-go on the inception

## MCP Tool Exposure

```json
{
  "name": "fw-pickup-receive",
  "description": "Receive a structured proposal from another project",
  "parameters": {
    "type": "object",
    "properties": {
      "pickup_type": {"enum": ["bug-report", "learning", "feature-proposal", "pattern"]},
      "summary": {"type": "string"},
      "detail": {"type": "string"},
      "source_project": {"type": "string"},
      "priority": {"enum": ["low", "medium", "high"]}
    },
    "required": ["pickup_type", "summary", "source_project"]
  }
}
```

The MCP tool would be a wrapper around the same intake flow — create inception, dedup, notify.

## Open Questions

- Q1: Should pickups queue to a file inbox when framework agent is offline? (Yes — `remote push` does this)
- Q2: Should the consumer project get an acknowledgement with the created task ID? (Nice to have — `agent ask` enables this)
- Q3: How to handle duplicate/spam pickups? (Dedup by summary similarity + cooldown window)
- Q4: Should `fw pickup send` be a command on the consumer side? (Yes — thin wrapper around `termlink remote push`)
