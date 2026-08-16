---
id: T-1209
name: "Fix Watchtower 500 on consumer home — datetime.date vs datetime.datetime in
  stale tasks"
description: >
  Fix Watchtower 500 on consumer home — datetime.date vs datetime.datetime in stale
  tasks

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/blueprints/core.py]
related_tasks: []
created: 2026-04-13T08:48:45Z
last_update: '2026-08-16T22:24:25Z'
date_finished: 2026-04-13T08:51:21Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
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
  - ts: '2026-08-16T22:24:25Z'
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

# T-1209: Fix Watchtower 500 on consumer home — datetime.date vs datetime.datetime in stale tasks

## Context

Consumer Watchtower home page returns 500. Root cause: `_get_stale_tasks()` in `web/blueprints/core.py`
does `now - last` where YAML parses `last_update`/`created` as `datetime.date` (not `datetime.datetime`).
Fix: coerce `datetime.date` to `datetime.datetime` before subtraction.

## Acceptance Criteria

### Agent
- [x] `_get_stale_tasks()` handles `datetime.date` objects from YAML
- [x] Framework Watchtower home page loads (HTTP 200)
- [x] Consumer Watchtower home page loads after restart

## Verification

# Framework home page loads
curl -sf -o /dev/null -w "%{http_code}" http://localhost:3000/ | grep -q 200

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

### 2026-04-13T08:48:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1209-fix-watchtower-500-on-consumer-home--dat.md
- **Context:** Initial task creation

### 2026-04-13T08:51:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e01df2b3
- **Timestamp:** 2026-06-02T14:55:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf -o /dev/null -w "%{http_code}" http://localhost:3000/ | grep -q 200`
