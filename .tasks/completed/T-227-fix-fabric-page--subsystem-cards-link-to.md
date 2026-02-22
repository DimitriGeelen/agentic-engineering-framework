---
id: T-227
name: "Fix fabric page — subsystem cards link to themselves, dropdown filters broken"
description: >
  Two bugs on /fabric page: (1) Subsystem cards always show all 12 tiles even when filtered, linking back to the same page — causes visual flicker/confusion. Fix: hide cards grid when filter active, show focused subsystem header instead. (2) Dropdown filter names (subsystem_filter, type_filter) don't match route params (subsystem, type) — dropdown filtering completely broken. Fix: rename select names to match route.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/templates/base.html, web/templates/fabric.html]
related_tasks: []
created: 2026-02-21T13:14:36Z
last_update: 2026-02-22T08:46:14Z
date_finished: 2026-02-21T13:20:58Z
---

# T-227: Fix fabric page — subsystem cards link to themselves, dropdown filters broken

## Context

Subsystem cards on `/fabric` linked to `/fabric?subsystem=X` — the same page with a filter. All 12 cards showed even when filtered, making navigation feel like "going back to the same page." Additionally, dropdown filter `name` attributes didn't match what the route handler reads.

## Acceptance Criteria

### Agent
- [x] Subsystem cards hidden when a subsystem filter is active
- [x] Focused subsystem header shown instead when filtered
- [x] Dropdown `name` attributes match route params (`subsystem`, `type`)
- [x] Search input `hx-include` references updated to match new names

### Human
- [x] Filtered view looks clean and navigation feels intentional

## Verification

curl -sf http://localhost:3000/fabric -o /tmp/t227-fabric.html && grep -q 'name="subsystem"' /tmp/t227-fabric.html
curl -sf "http://localhost:3000/fabric?subsystem=context-fabric" -o /tmp/t227-filtered.html && grep -q 'border-left' /tmp/t227-filtered.html

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

### 2026-02-21T13:14:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-227-fix-fabric-page--subsystem-cards-link-to.md
- **Context:** Initial task creation

### 2026-02-21T13:20:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
