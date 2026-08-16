---
id: T-382
name: "API endpoint for search Q&A (non-streaming JSON)"
description: >
  API endpoint for search Q&A (non-streaming JSON)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [api, search]
components: []
related_tasks: []
created: 2026-03-09T10:36:44Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-09T10:42:47Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-382: API endpoint for search Q&A (non-streaming JSON)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] web/blueprints/api.py created with /api/v1/ask, /api/v1/search, /api/v1/health
- [x] Blueprint registered in app.py
- [x] CSRF exempted for /api/ routes
- [x] /api/v1/health returns 200 with provider info
- [x] /api/v1/search returns JSON results

## Verification

curl -sf http://localhost:3000/api/v1/health | python3 -c "import sys,json; assert json.load(sys.stdin)['status']=='ok'"
curl -sf "http://localhost:3000/api/v1/search?q=healing&mode=keyword" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['total']>0"

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

### 2026-03-09T10:36:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-382-api-endpoint-for-search-qa-non-streaming.md
- **Context:** Initial task creation

### 2026-03-09T10:42:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-45e5dfe8
- **Timestamp:** 2026-06-02T15:02:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — web/blueprints/api.py created with /api/v1/ask, /api/v1/search, /api/v1/health
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/api.py in: web/blueprints/api.py created with /api/v1/ask, /api/v1/search, /api/v1/health`
