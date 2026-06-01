---
id: T-668
name: "Add /review/T-XXX mobile link to approvals page Human AC cards"
description: >
  Add /review/T-XXX mobile link to approvals page Human AC cards

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/templates/approvals.html]
related_tasks: []
created: 2026-03-28T17:56:55Z
last_update: 2026-03-28T18:00:12Z
date_finished: 2026-03-28T18:00:12Z
---

# T-668: Add /review/T-XXX mobile link to approvals page Human AC cards

## Context

Connect desktop approvals page to mobile review flow. Each Human AC task card gets a mobile review icon/link to `/review/T-XXX`. Connects T-667 mobile review to T-639 approvals page.

## Acceptance Criteria

### Agent
- [x] Each Human AC task card in approvals.html has a `/review/T-XXX` link
- [x] Link uses a phone/mobile icon to indicate "mobile review"
- [x] Link renders correctly on the approvals page

## Verification

grep -q 'href="/review/' web/templates/approvals.html

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

### 2026-03-28T17:56:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-668-add-reviewt-xxx-mobile-link-to-approvals.md
- **Context:** Initial task creation

### 2026-03-28T18:00:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
