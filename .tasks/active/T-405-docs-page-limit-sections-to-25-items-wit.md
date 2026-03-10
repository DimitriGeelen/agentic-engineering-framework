---
id: T-405
name: "Docs page: limit sections to 25 items with Show All links"
description: >
  Project Documentation page (/project) shows all items per section, making Research (398) and Design (293)
  sections overwhelming. Show 25 items by default per section with a "Show all N items" link to expand.
  Also remove the hardcoded [:25] limit on episodic loading so all items are available.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [watchtower, ux]
components: []
related_tasks: []
created: 2026-03-10T13:45:24Z
last_update: 2026-03-10T22:04:14Z
date_finished: 2026-03-10T13:47:16Z
---

# T-405: Docs page: limit sections to 25 items with Show All links

## Context

Research section showed only 25 of 398 episodic summaries with no way to see the rest.
Design section (293 items) also needed truncation. Added client-side Show All toggle.

## Acceptance Criteria

### Agent
- [x] Remove hardcoded `[:25]` episodic limit in core.py (all items loaded)
- [x] Template shows max 25 items per section by default
- [x] "Show all N items" link appears for sections with >25 items
- [x] Clicking link reveals all hidden items
- [x] Sections with <=25 items show all items (no link)

### Human
- [ ] [REVIEW] Docs page sections look clean with Show All links
  **Steps:**
  1. Open http://localhost:3000/project in browser
  2. Scroll to "Research" section — should show 25 items + "Show all 398 items" link
  3. Click "Show all 398 items" — all episodic summaries expand
  4. Check "Design" section has same behavior
  **Expected:** Sections truncated at 25, link expands to show all, small sections unaffected
  **If not:** Check browser console for JS errors

## Verification

curl -sf http://localhost:3000/project > /dev/null
grep -q "docs-show-all" web/templates/project.html
grep -q "docs-overflow" web/templates/project.html
! grep -q "episodics\[:25\]" web/blueprints/core.py

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

### 2026-03-10T13:45:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-405-docs-page-limit-sections-to-25-items-wit.md
- **Context:** Initial task creation

### 2026-03-10T13:47:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
