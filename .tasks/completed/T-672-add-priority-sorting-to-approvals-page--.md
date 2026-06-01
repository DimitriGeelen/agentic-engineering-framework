---
id: T-672
name: "Add priority sorting to approvals page — urgent/stale items first, rubber-stamps last"
description: >
  Add priority sorting to approvals page — urgent/stale items first, rubber-stamps last

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-28T19:47:59Z
last_update: 2026-03-28T19:50:01Z
date_finished: 2026-03-28T19:50:01Z
---

# T-672: Add priority sorting to approvals page — urgent/stale items first, rubber-stamps last

## Context

The Human AC section on /approvals currently shows tasks in arbitrary order. With 40+ tasks, the user needs prioritization: [REVIEW] items first (need judgment), then stale items (>7d), then [RUBBER-STAMP] items (mechanical). Also add age indicator to each task card.

## Acceptance Criteria

### Agent
- [x] Human AC tasks sorted: REVIEW items first, then by age (oldest first), then RUBBER-STAMP
- [x] Each task card shows age indicator (e.g., "15d ago")
- [x] Stale tasks (>7d) have visual highlight (orange warning icon)

## Verification

grep -q 'sort_key\|priority' web/blueprints/approvals.py

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

### 2026-03-28T19:47:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-672-add-priority-sorting-to-approvals-page--.md
- **Context:** Initial task creation

### 2026-03-28T19:50:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
