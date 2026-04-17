---
id: T-1286
name: "Watchtower /api/_identity endpoint (T-1284 B1)"
description: >
  Watchtower /api/_identity endpoint (T-1284 B1)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-17T19:41:46Z
last_update: 2026-04-17T19:41:46Z
date_finished: null
---

# T-1286: Watchtower /api/_identity endpoint (T-1284 B1)

## Context

B1 of T-1284 redesign. Adds `/api/_identity` to Watchtower so callers
(including `_watchtower_url` after B3) can verify a responding service
actually IS Watchtower, not a masquerading sibling (T-1284 root cause
was Open WebUI on :8080 matching a task-specific probe).

Returns JSON: `service`, `version`, `project_root`, `started_at`.
No auth, no CSRF, GET-only. Idempotent, trivial cost.

## Acceptance Criteria

### Agent
- [x] `/api/_identity` returns 200 with JSON body containing keys
      `service`, `version`, `project_root`, `started_at`
- [x] `service` equals the literal string `watchtower`
- [x] `project_root` equals the current PROJECT_ROOT (absolute path)
- [x] Endpoint is reachable on both 127.0.0.1:3000 and LAN IP:3000
- [x] Handler costs < 50ms on cold request (no ollama calls, no DB, no git)

## Verification

curl -sf --max-time 3 http://127.0.0.1:3000/api/_identity -o /tmp/_identity.json
python3 -c "import json; d=json.load(open('/tmp/_identity.json')); assert d['service']=='watchtower', d; assert 'version' in d; assert 'project_root' in d; assert 'started_at' in d; print('ok', d)"
python3 -c "import json,os; d=json.load(open('/tmp/_identity.json')); assert d['project_root']==os.environ.get('PROJECT_ROOT','/opt/999-Agentic-Engineering-Framework'), (d['project_root'], os.environ.get('PROJECT_ROOT'))"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-17T19:41:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1286-watchtower-apiidentity-endpoint-t-1284-b.md
- **Context:** Initial task creation
