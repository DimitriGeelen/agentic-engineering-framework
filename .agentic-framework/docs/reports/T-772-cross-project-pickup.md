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

## Open Questions (Resolved)

- Q1: Should pickups queue to a file inbox when framework agent is offline? **Yes** — `remote push` does this, file-based inbox is the primary mechanism
- Q2: Should the consumer project get an acknowledgement with the created task ID? **Nice to have** — `agent ask` enables this as upgrade path
- Q3: How to handle duplicate/spam pickups? **Dedup by SHA256(type + summary_normalized + source_project) with 7-day cooldown window**
- Q4: Should `fw pickup send` be a command on the consumer side? **Yes** — thin wrapper around `termlink remote push` for remote, direct write for local

---

## Pipeline Design (GO Decision — 2026-03-30)

### Architecture: One Pipeline, Two Transports

```
Consumer Project                          Framework
       |                                      |
       |  [Local] fw pickup send              |
       |  → writes YAML to .context/pickup/inbox/
       |                                      |
       |  [TermLink] fw pickup send --remote  |
       |  → termlink remote push → inbox/     |
       |                                      |
       |         fw pickup process            |
       |         (cron every 15 min)          |
       |         ↓                            |
       |   parse → validate → dedup →         |
       |   create inception → notify →        |
       |   move to processed/                 |
```

Both transports feed the same deterministic processing backend.

### Pickup Envelope Schema

```yaml
# .context/pickup/inbox/P-001-bug-report.yaml
---
pickup_id: P-001
version: 1
type: bug-report          # bug-report | learning | feature-proposal | pattern
source:
  project: "vinix24"
  task_id: "T-042"        # originating task (optional)
  agent: "claude-code"
  timestamp: "2026-03-30T12:00:00Z"
payload:
  summary: "fw audit false FAILs on JSON validation"
  detail: |
    The audit check for JSON files uses `python3 -c "import json; ..."`
    but the exit code is not captured correctly. Affects fw audit when
    consumer project has JSON config files.
  evidence: "agents/audit/audit.sh:245"
  priority: high
  tags: [audit, json, validation]
result:
  status: pending          # pending | accepted | rejected | duplicate
  task_created: ""         # T-XXX if accepted
  processed_at: ""
  dedup_hash: ""           # SHA256(type + summary_normalized + source_project)
```

### Directory Structure

```
.context/pickup/
  inbox/          # Unprocessed pickups (YAML envelopes)
  processed/      # Completed pickups (moved after processing)
  rejected/       # Rejected or duplicate pickups
```

### Pipeline Guarantees

| Property | How |
|----------|-----|
| **Idempotent** | SHA256 dedup hash, 7-day cooldown window |
| **Deterministic** | Same input → same output, no randomness |
| **Auditable** | Every pickup gets a result block, processed files preserved |
| **Persistent** | File-based inbox survives agent restarts |
| **Governance-safe** | Always creates inception task, never direct build (T-469 lesson) |
| **Human-gated** | Inception requires human GO decision before any build work |

### Dedup Strategy

```
hash = SHA256(type + lowercase(summary).strip() + source_project)
```

Check against all processed pickups within 7-day window. If hash matches → mark as `duplicate`, do not create task.

### CLI Commands

| Command | Purpose |
|---------|---------|
| `fw pickup send` | Consumer-side: serialize envelope + write to inbox (local) |
| `fw pickup send --remote hub-addr` | Consumer-side: serialize + push via TermLink |
| `fw pickup process` | Framework-side: scan inbox, process all pending envelopes |
| `fw pickup list` | Show inbox contents with status |
| `fw pickup reject P-NNN --reason "..."` | Manually reject a pickup |

### Cron Integration

```yaml
# In cron registry
pickup-process:
  schedule: "*/15 * * * *"
  command: "bin/fw pickup process"
  description: "Process incoming pickup envelopes"
```

### Strawman Risk Mitigations

| Risk | Mitigation |
|------|------------|
| Bus v2 trap (building infra nobody uses) | Process existing pickup-051-vinix24 on day 1 — proves pipeline with real data |
| Complexity creep | Strict scope: file I/O + YAML parse + task create. No message brokers, no databases |
| TermLink dependency | Local transport works without TermLink. TermLink is upgrade path, not requirement |
| Spam/flooding | Dedup hash + 7-day cooldown + rate limit (max 10 per source per day) |

### Build Tasks (from GO decision)

1. **Pickup pipeline core** — `lib/pickup.sh` with receive/process/dedup/log functions
2. **`fw pickup send`** — consumer-side CLI (serialize + write to inbox or termlink remote push)
3. **`fw pickup process`** — cron-triggered inbox scanner (deterministic, idempotent)
4. **Observation inbox migration** — process existing pickup-051-vinix24 through the pipeline
5. **TermLink transport** — `fw pickup send --remote hub-addr` using `termlink remote push`
6. **Cron registration** — add pickup-process to cron registry
