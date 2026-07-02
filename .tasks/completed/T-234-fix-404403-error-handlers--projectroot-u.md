---
id: T-234
name: "Fix 404/403 error handlers — project_root undefined in base.html"
description: >
  Fix 404/403 error handlers — project_root undefined in base.html

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [web/app.py]
related_tasks: []
created: 2026-02-21T20:44:57Z
last_update: '2026-06-11T22:24:16Z'
date_finished: 2026-02-21T20:47:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:16Z'
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
---

# T-234: Fix 404/403 error handlers — project_root undefined in base.html

## Context

The `_error_context()` function in `web/app.py` provides template context for 403/404 error handlers but was missing `project_root`. Since `base.html` references `{{ project_root }}` in the footer, every error page crashed with a Jinja2 `UndefinedError`, turning 404s into 500s. Additionally, `PROJECT_ROOT` was not imported at module level.

## Acceptance Criteria

### Agent
- [x] `_error_context()` includes `project_root` in returned dict
- [x] `PROJECT_ROOT` imported at module level in `web/app.py`
- [x] 404 pages return HTTP 404 (not 500)
- [x] Homepage still returns HTTP 200

## Verification

curl -s http://localhost:3000/nonexistent-page -o /dev/null -w "%{http_code}" | grep -q "404"
curl -sf http://localhost:3000/ -o /dev/null -w "%{http_code}" | grep -q "200"

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

### 2026-02-21T20:44:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-234-fix-404403-error-handlers--projectroot-u.md
- **Context:** Initial task creation

### 2026-02-21T20:47:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7dce7a5e
- **Timestamp:** 2026-06-02T15:01:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#2 (Agent)** — `PROJECT_ROOT` imported at module level in `web/app.py`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/app.py in: `PROJECT_ROOT` imported at module level in `web/app.py``

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -s http://localhost:3000/nonexistent-page -o /dev/null -w "%{http_code}" | grep -q "404"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/ -o /dev/null -w "%{http_code}" | grep -q "200"`
