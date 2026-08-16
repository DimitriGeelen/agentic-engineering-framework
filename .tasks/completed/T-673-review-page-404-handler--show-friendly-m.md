---
id: T-673
name: "Review page 404 handler — show friendly message when task not found"
description: >
  Review page 404 handler — show friendly message when task not found

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T19:50:28Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-28T19:52:25Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
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
  - ts: '2026-08-16T22:25:36Z'
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

# T-673: Review page 404 handler — show friendly message when task not found

## Context

The /review/T-XXX route currently returns Flask's default 404 for invalid task IDs. Replace with a mobile-friendly standalone page that explains the issue and links back to /approvals. Also handle completed tasks gracefully (show "already completed" message with link to view).

## Acceptance Criteria

### Agent
- [x] `/review/T-999` (nonexistent) returns a styled mobile-friendly 404 page
- [x] `/review/T-XXX` for completed tasks shows "task completed" message
- [x] Both error pages are standalone (no base.html), matching review.html style

## Verification

grep -q 'review_not_found\|review_404' web/blueprints/review.py

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

### 2026-03-28T19:50:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-673-review-page-404-handler--show-friendly-m.md
- **Context:** Initial task creation

### 2026-03-28T19:52:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f03aa8a8
- **Timestamp:** 2026-06-02T15:04:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
