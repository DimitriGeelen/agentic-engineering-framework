---
id: T-380
name: "Search UX redesign: unified input, elevated Q&A, relevance bars"
description: >
  Redesign search page: unified smart input (auto-detect search vs Q&A), AI answer above results in distinct article, category pills replacing accordions, 5-segment relevance bars, empty state with suggestions. Depends on T-376 (search_utils dedup). Parent: T-375.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [ui, search]
components: [C-003, web/templates/search.html]
related_tasks: []
created: 2026-03-09T09:41:43Z
last_update: 2026-03-12T12:41:19Z
date_finished: 2026-03-09T10:06:25Z
---

# T-380: Search UX redesign: unified input, elevated Q&A, relevance bars

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Unified search input with auto-detect (questions trigger Q&A, keywords trigger search)
- [x] AI answer elevated to distinct article above results (not hidden in details)
- [x] Category pills replace accordion details for filtering
- [x] 5-segment relevance bars with labels replace raw scores
- [x] Empty state with suggestion pills
- [x] path_to_link Jinja2 filter used for server-side path resolution
- [x] Default search mode changed from keyword to hybrid
- [x] Follow-up input for multi-turn conversations
- [x] All search tests pass

### Human
- [x] [REVIEW] Search UX feels intuitive and looks good
  **Steps:**
  1. Open http://localhost:3000/search
  2. Try a keyword search: "healing loop"
  3. Try a question: "How does the audit system work?"
  4. Check relevance bars and category pills
  5. Check mobile layout (resize browser to 400px wide)
  **Expected:** Clean layout, Q&A auto-triggers on questions, pills filter results, bars show relevance
  **If not:** Note which element looks off

## Verification

curl -sf http://localhost:3000/search | grep -q "Search or ask"
curl -sf "http://localhost:3000/search?q=healing&mode=hybrid" | grep -q "search-result"

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

### 2026-03-09T09:41:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-380-search-ux-redesign-unified-input-elevate.md
- **Context:** Initial task creation

### 2026-03-09T09:57:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T10:06:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
