---
id: T-645
name: "Landing page summary card — replace full Human AC list with counts + top 3
  + /approvals link"
description: >
  Landing page summary card — replace full Human AC list with counts + top 3 + /approvals
  link

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-27T12:38:18Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-27T13:57:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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

# T-645: Landing page summary card — replace full Human AC list with counts + top 3 + /approvals link

## Context

T-644 build task. Replace landing page "Awaiting Your Verification" full list with a compact summary card showing unified counts (Tier 0 + GO + Human ACs) and top 3 tasks, linking to /approvals as the action hub. Also enrich /approvals Human ACs with expandable detail cards.

## Acceptance Criteria

### Agent
- [x] Landing page shows unified "Action Required" summary with counts
- [x] Top 3 most-AC tasks shown as preview
- [x] "View all in Approvals" link present
- [x] /approvals Human AC cards have expandable Steps/Expected/If-not
- [x] Per-task "Complete Task" button on /approvals when all ACs checked
- [x] Landing page loads without errors

### Human
- [x] [REVIEW] Landing page summary card looks clean and useful
  **Steps:**
  1. Open http://192.168.10.107:8089/ in browser
  2. Verify "Action Required" summary replaces old full list
  3. Click "View all in Approvals" link
  4. On /approvals, expand a Human AC to see Steps/Expected
  **Expected:** Summary card is concise, /approvals has full detail
  **If not:** Note what's missing or broken

## Verification

grep -q 'Action Required' web/templates/cockpit.html
grep -q 'View all in Approvals' web/templates/cockpit.html
grep -q 'action_summary' web/blueprints/cockpit.py

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

### 2026-03-27T12:38:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-645-landing-page-summary-card--replace-full-.md
- **Context:** Initial task creation

### 2026-03-27T13:57:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-77187a69
- **Timestamp:** 2026-06-02T15:04:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
