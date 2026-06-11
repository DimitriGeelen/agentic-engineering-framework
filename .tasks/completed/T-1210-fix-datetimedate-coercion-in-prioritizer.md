---
id: T-1210
name: "Fix datetime.date coercion in prioritizer.py and rules.py (T-1209 follow-up)"
description: >
  Fix datetime.date coercion in prioritizer.py and rules.py (T-1209 follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T09:00:19Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T09:02:29Z
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
---

# T-1210: Fix datetime.date coercion in prioritizer.py and rules.py (T-1209 follow-up)

## Context

Same datetime.date bug class as T-1209. `_parse_datetime()` in prioritizer.py and date handling
in rules.py don't handle YAML date objects. Follow-up to ensure the bug class is eliminated.

## Acceptance Criteria

### Agent
- [x] prioritizer.py `_parse_datetime()` handles `datetime.date` objects
- [x] rules.py date handling handles `datetime.date` objects (already fixed)
- [x] Watchtower health endpoint returns ok after restart

## Verification

# Watchtower health check
curl -sf http://localhost:3001/health | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['app']=='ok', f'unhealthy: {d}'"

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

### 2026-04-13T09:00:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1210-fix-datetimedate-coercion-in-prioritizer.md
- **Context:** Initial task creation

### 2026-04-13T09:02:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8c05b4e4
- **Timestamp:** 2026-06-02T14:55:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
