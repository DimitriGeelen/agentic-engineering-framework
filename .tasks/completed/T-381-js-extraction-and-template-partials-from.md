---
id: T-381
name: "JS extraction and template partials from search.html"
description: >
  Extract 416 lines of inline JS from search.html into web/static/js/{utils.js, markdown-render.js, search-qa.js}. Create Jinja2 partials in web/templates/_partials/. Reduce search.html from 567 to ~15 lines. Depends on T-380 (UX redesign). Parent: T-375.

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: [ui, refactor]
components: []
related_tasks: []
created: 2026-03-09T09:41:45Z
last_update: 2026-03-09T10:36:13Z
date_finished: 2026-03-09T10:36:13Z
---

# T-381: JS extraction and template partials from search.html

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Inline JS extracted into web/static/js/{utils.js, markdown-render.js, search-qa.js}
- [x] Jinja2 partials created in web/templates/_partials/{search_input, ask_answer_card, search_results}.html
- [x] search.html reduced to includes + script tags (~30 lines)
- [x] All 3 JS files served correctly via /static/js/
- [x] Search page renders with partials (keyword mode verified)

## Verification

curl -sf http://localhost:3000/search | grep -q 'utils.js'
curl -sf http://localhost:3000/static/js/utils.js | grep -q 'escHtml'
curl -sf http://localhost:3000/static/js/search-qa.js | grep -q 'askQuestion'

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

### 2026-03-09T09:41:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-381-js-extraction-and-template-partials-from.md
- **Context:** Initial task creation

### 2026-03-09T10:24:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T10:36:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5f6a74c9
- **Timestamp:** 2026-06-02T15:02:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/search | grep -q 'utils.js'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/static/js/utils.js | grep -q 'escHtml'`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf http://localhost:3000/static/js/search-qa.js | grep -q 'askQuestion'`
