---
id: T-643
name: "Htmx-ify GO decision form — inline response on /approvals page"
description: >
  Htmx-ify GO decision form — inline response on /approvals page

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-27T12:21:37Z
last_update: 2026-03-27T12:22:36Z
date_finished: 2026-03-27T12:22:36Z
---

# T-643: Htmx-ify GO decision form — inline response on /approvals page

## Context

T-636 Phase 2. GO decision forms on /approvals do a full page redirect. Make them htmx-friendly: return inline fragment when HX-Request header present, keep redirect for direct /inception page.

## Acceptance Criteria

### Agent
- [x] /inception/<T-XXX>/decide returns HTML fragment when HX-Request header present
- [x] Full redirect preserved when called without HX-Request (from inception detail page)
- [x] /approvals GO decision form uses hx-post for inline swap

## Verification

grep -q 'HX-Request' web/blueprints/inception.py

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

### 2026-03-27T12:21:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-643-htmx-ify-go-decision-form--inline-respon.md
- **Context:** Initial task creation

### 2026-03-27T12:22:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
