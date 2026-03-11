---
id: T-427
name: "Python utility consolidation — task parser, search routing, SSE formatter (P4+P8+P9)"
description: >
  P4: Task frontmatter parsing duplicated 4x — extract parse_task_markdown(). P8: search routing 70+ lines/4 levels — extract select_search_mode(). P9: SSE duplication between discovery.py and ask.py — create web/sse.py utility. Directive scores: P4=6, P8=5, P9=5. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: started-work
workflow_type: refactor
owner: agent
horizon: next
tags: [refactoring, python, watchtower]
components: []
related_tasks: [T-411]
created: 2026-03-10T21:04:08Z
last_update: 2026-03-11T21:49:28Z
date_finished: null
---

# T-427: Python utility consolidation — task parser, search routing, SSE formatter (P4+P8+P9)

## Context

Python utility consolidation (P4+P8+P9). See `docs/reports/T-411-refactoring-directive-scoring.md` § PYTHON rows P4 (task parser, score 6), P8 (search routing, score 5), P9 (SSE dedup, score 5). Three independent improvements that reduce discovery.py complexity.

## Acceptance Criteria

### Agent
- [x] P4: parse_frontmatter() in web/shared.py replaces 11+ inline regex/yaml patterns
- [x] P8: _execute_search() extracted — search_view() reduced from 74 to ~10 lines of search logic
- [x] P9: sse_event() in web/shared.py replaces f-string SSE formatting in ask.py and discovery.py
- [x] All Python imports succeed
- [x] All web pages load (dashboard, search, tasks, timeline)

### Human
- [ ] [REVIEW] Search and Q&A still work after routing refactor
  **Steps:**
  1. Open http://localhost:3000/search in browser
  2. Search for "task" (keyword mode)
  3. Ask "how does the healing loop work?" (Q&A mode)
  **Expected:** Both search results and Q&A answers render correctly
  **If not:** Note which mode broke and check Flask logs

## Verification

# parse_frontmatter exists in shared.py
grep -q "def parse_frontmatter" web/shared.py
# sse_event exists in shared.py
grep -q "def sse_event" web/shared.py
# _execute_search exists in discovery.py
grep -q "def _execute_search" web/blueprints/discovery.py
# All imports work
python3 -c "from web.shared import parse_frontmatter, sse_event"
python3 -c "from web.ask import stream_answer"
python3 -c "from web.blueprints.discovery import bp"
# Web pages load
curl -sf http://localhost:3000/ > /dev/null
curl -sf http://localhost:3000/search > /dev/null
curl -sf http://localhost:3000/tasks > /dev/null

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

### 2026-03-10T21:04:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-427-python-utility-consolidation--task-parse.md
- **Context:** Initial task creation

### 2026-03-11T21:49:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
