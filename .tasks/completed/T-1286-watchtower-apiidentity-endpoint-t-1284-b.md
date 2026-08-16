---
id: T-1286
name: "Watchtower /api/_identity endpoint (T-1284 B1)"
description: >
  Watchtower /api/_identity endpoint (T-1284 B1)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/app.py]
related_tasks: []
created: 2026-04-17T19:41:46Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-04-17T22:33:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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

# Static checks — endpoint and helpers are registered in the Flask app
grep -q '@app.route("/api/_identity")' web/app.py
grep -q '"service": "watchtower"' web/app.py
grep -q '"project_root": str(PROJECT_ROOT)' web/app.py
grep -q '"started_at"' web/app.py
python3 -c "import ast; ast.parse(open('web/app.py').read()); print('app.py parses ok')"

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

### 2026-04-17T22:33:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b4e29f42
- **Timestamp:** 2026-06-02T14:56:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
