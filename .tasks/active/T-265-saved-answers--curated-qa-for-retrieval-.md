---
id: T-265
name: "Saved answers — curated Q&A for retrieval flywheel"
description: >
  Add 'Save Answer' button to Q&A UI. Saved answers stored as .context/qa/YYYY-MM-DD-{slug}.md with question, answer, sources, date. Files get indexed by existing BM25+vector search infrastructure on next rebuild. Creates a knowledge flywheel: good answers become first-class retrieval sources for future queries. Implementation: POST /search/save endpoint (~20 lines in discovery.py), save-answer JS function (~15 lines in search.html), .context/qa/ directory. Ref: conversation Q3 in docs/reports/T-261-qa-phase2-research.md §Dialogue Log Q3. Predecessor: T-256 (ask endpoint), T-257 (frontend).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [qa, knowledge, search]
components: [C-003, web/embeddings.py, web/search.py, web/templates/search.html]
related_tasks: []
created: 2026-02-24T08:37:11Z
last_update: 2026-02-24T10:09:38Z
date_finished: 2026-02-24T10:09:38Z
---

# T-265: Saved answers — curated Q&A for retrieval flywheel

## Context

Save Answer button on Q&A UI creates curated knowledge files that get indexed by BM25+vector search. Ref: T-261 research §Q3.

## Acceptance Criteria

### Agent
- [x] POST /search/save endpoint in discovery blueprint
- [x] Saves to .context/qa/YYYY-MM-DD-{slug}.md with question, answer, sources
- [x] .context/qa/ directory exists
- [x] Both BM25 and vector search index .context/qa/ files
- [x] BM25 categorizes qa files as "Saved Answers"
- [x] Save Answer button in search.html with JS save function
- [x] Button appears after answer completes, shows saved path on success

### Human
- [ ] Save button works in browser — click produces file in .context/qa/
- [ ] Saved answer appears in search results after index rebuild

## Verification

# POST endpoint exists
grep -q "search/save" web/blueprints/discovery.py
# qa directory exists
test -d .context/qa
# BM25 indexes qa directory
grep -q "context.*qa" web/search.py
# Vector search indexes qa directory
grep -q "context.*qa" web/embeddings.py
# Save button in template
grep -q "saveAnswer" web/templates/search.html
# Categorizer for saved answers
grep -q "Saved Answers" web/search.py

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

### 2026-02-24T08:37:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-265-saved-answers--curated-qa-for-retrieval-.md
- **Context:** Initial task creation

### 2026-02-24T10:04:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-24T10:09:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
