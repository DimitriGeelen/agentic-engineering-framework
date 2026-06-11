---
id: T-984
name: "Add Sessions link to Watchtower navigation"
description: >
  Add /sessions to the site navigation bar so users can access the sessions management
  page.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/shared.py]
related_tasks: []
created: 2026-04-06T23:24:00Z
last_update: '2026-06-11T22:24:34Z'
date_finished: 2026-04-06T23:25:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:34Z'
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

# T-984: Add Sessions link to Watchtower navigation

## Context

T-983 created /sessions page. Add it to the navigation bar under Architecture group next to Terminal.

## Acceptance Criteria

### Agent
- [x] `web/shared.py` NAV_GROUPS updated with Sessions link under Architecture
- [x] /sessions appears in navigation on any page

## Verification

grep -q 'sessions_page' web/shared.py
curl -sf http://localhost:3000/ -o /tmp/fw-verify-sessions.html && grep -q 'Sessions' /tmp/fw-verify-sessions.html

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

### 2026-04-06T23:24:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-984-add-sessions-link-to-watchtower-navigati.md
- **Context:** Initial task creation

### 2026-04-06T23:25:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-94b24490
- **Timestamp:** 2026-06-02T15:06:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
