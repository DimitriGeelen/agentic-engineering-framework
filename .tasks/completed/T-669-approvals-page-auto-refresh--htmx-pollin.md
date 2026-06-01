---
id: T-669
name: "Approvals page auto-refresh — htmx polling for live Tier 0 and Human AC updates"
description: >
  Approvals page auto-refresh — htmx polling for live Tier 0 and Human AC updates

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-28T18:01:21Z
last_update: 2026-03-28T18:06:01Z
date_finished: 2026-03-28T18:06:01Z
---

# T-669: Approvals page auto-refresh — htmx polling for live Tier 0 and Human AC updates

## Context

The /approvals page shows Tier 0, GO decisions, and Human ACs but requires manual page refresh to see changes. Add htmx polling to auto-refresh, matching the pattern from /review/T-XXX (T-667).

## Acceptance Criteria

### Agent
- [x] Approvals page wraps dynamic content in a polling div
- [x] Polling interval is 10 seconds
- [x] `/approvals/content` endpoint returns fragment without wrapper
- [x] Page updates show new Tier 0 approvals and AC state changes without full reload

## Verification

grep -q hx-trigger web/templates/approvals.html
grep -q approvals_content web/blueprints/approvals.py

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

### 2026-03-28T18:01:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-669-approvals-page-auto-refresh--htmx-pollin.md
- **Context:** Initial task creation

### 2026-03-28T18:06:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
