---
id: T-620
name: "Human AC approval buttons in Watchtower — check/uncheck Human ACs from web
  UI"
description: >
  Add approve/reject buttons for Human ACs on the Watchtower task detail page. When
  a human clicks approve, it checks the AC checkbox in the task markdown file. This
  completes the T-608 approval surface chain: T-610 (parse ACs) → T-611 (Tier 0 queue)
  → T-612 (agent pickup) → this task (Human AC buttons).

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [web/blueprints/tasks.py, web/templates/task_detail.html]
related_tasks: []
created: 2026-03-25T21:45:49Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-26T12:30:46Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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

# T-620: Human AC approval buttons in Watchtower — check/uncheck Human ACs from web UI

## Context

Human AC checkboxes in task_detail.html are rendered as `disabled` with no form — users can see them but not approve/reject from the web UI. Agent ACs already have interactive toggle-ac forms. This adds the same for Human ACs.

Related: T-608 → T-610 (parse ACs) → T-611 (Tier 0 queue) → T-612 (agent pickup)

## Acceptance Criteria

### Agent
- [x] Human AC checkboxes in task_detail.html are wrapped in a toggle-ac form (not disabled)
- [x] Clicking a Human AC checkbox POSTs to /api/task/<id>/toggle-ac and updates the task file
- [x] curl test: POST to toggle-ac endpoint returns updated checkbox HTML

### Human
- [x] [RUBBER-STAMP] Human AC checkboxes are clickable in Watchtower task detail
  **Steps:**
  1. Open http://192.168.10.107:8050/tasks/T-614
  2. Scroll to Human ACs section
  3. Click a Human AC checkbox
  **Expected:** Checkbox toggles, task file updated on disk
  **If not:** Check browser console for errors, verify CSRF token

## Verification

curl -sf http://localhost:8050/tasks/T-614 | grep -q 'hx-post="/api/task/T-614/toggle-ac"'

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

### 2026-03-25T21:45:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-620-human-ac-approval-buttons-in-watchtower-.md
- **Context:** Initial task creation

### 2026-03-25T21:46:13Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-03-25T21:47:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-26T12:30:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a60edd7c
- **Timestamp:** 2026-06-02T15:03:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:8050/tasks/T-614 | grep -q 'hx-post="/api/task/T-614/toggle-ac"'`
