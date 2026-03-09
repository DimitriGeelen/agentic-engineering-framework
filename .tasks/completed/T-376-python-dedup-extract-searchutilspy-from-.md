---
id: T-376
name: "Python dedup: extract search_utils.py from search.py/embeddings.py"
description: >
  Extract duplicated functions (_categorize, _extract_title, _extract_task_id, _collect_files, path-to-link) from web/search.py and web/embeddings.py into web/search_utils.py. Register as Jinja2 filter. Parent: T-375.

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: [web/app.py, web/embeddings.py, web/search.py, web/search_utils.py]
related_tasks: []
created: 2026-03-09T09:41:20Z
last_update: 2026-03-09T09:47:27Z
date_finished: 2026-03-09T09:47:27Z
---

# T-376: Python dedup: extract search_utils.py from search.py/embeddings.py

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] web/search_utils.py created with categorize, extract_title, extract_task_id, collect_files, path_to_link
- [x] search.py and embeddings.py import from search_utils instead of defining duplicates
- [x] path_to_link registered as Jinja2 filter in app.py
- [x] All search tests pass

## Verification

python3 -c "from web.search_utils import categorize, extract_title, extract_task_id, collect_files, path_to_link; print('OK')"
python3 -c "from web.search import search; print('OK')"
python3 -c "from web.embeddings import search; print('OK')"

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

### 2026-03-09T09:41:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-376-python-dedup-extract-searchutilspy-from-.md
- **Context:** Initial task creation

### 2026-03-09T09:47:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
