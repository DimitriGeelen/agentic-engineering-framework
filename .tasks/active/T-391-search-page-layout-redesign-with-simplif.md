---
id: T-391
name: "Search page layout redesign with simplified mode UX"
description: >
  Redesign the search page layout for cohesion. Replace technical mode dropdown (Hybrid/Keyword/Semantic) with clear Search vs Ask toggle. Clean up visual hierarchy: prominent search bar, clear mode selection, organized secondary elements (recent searches, saved answers). Use frontend-design skill for the redesign. Predecessor: T-388.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-09T11:36:04Z
last_update: 2026-03-09T12:45:41Z
date_finished: 2026-03-09T12:45:41Z
---

# T-391: Search page layout redesign with simplified mode UX

## Context

Redesign search page from T-388 inception. Replace confusing mode dropdown with segmented pills, fix cramped search bar (caused by Pico CSS fieldset equal-width children), clean up visual hierarchy.

## Acceptance Criteria

### Agent
- [x] Search bar full-width (Pico fieldset group with flex override)
- [x] Mode dropdown replaced with segmented pill buttons (All/Keyword/Semantic)
- [x] Hidden select synced with pill clicks for form submission
- [x] Pill active state persists on page reload (server-rendered from mode param)
- [x] Gear icon circular with hover state
- [x] Hint text on same row as pills
- [x] Search with mode=keyword works correctly (URL reflects selected mode)

### Human
- [ ] [REVIEW] Search page layout looks clean and natural
  **Steps:**
  1. Open http://localhost:3000/search
  2. Check search bar is full width with readable placeholder
  3. Click each mode pill (All, Keyword, Semantic) — active state should toggle
  4. Search for "healing loop" — results should load, pill state should persist
  5. Ask a question like "how does the audit system work?" — AI answer should stream
  **Expected:** Clean layout, pills work, search and Q&A both functional
  **If not:** Note which element looks off or doesn't work

## Verification

curl -sf http://localhost:3000/search | grep -q mode-pill
curl -sf http://localhost:3000/search | grep -q search-mode-select

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

### 2026-03-09T11:36:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-391-search-page-layout-redesign-with-simplif.md
- **Context:** Initial task creation

### 2026-03-09T12:45:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
