---
id: T-673
name: "Review page 404 handler — show friendly message when task not found"
description: >
  Review page 404 handler — show friendly message when task not found

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-28T19:50:28Z
last_update: 2026-03-28T22:35:54Z
date_finished: 2026-03-28T19:52:25Z
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
