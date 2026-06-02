---
id: T-1295
name: "Watchtower prompt register list + detail pages (T-1283 B3)"
description: >
  Watchtower prompt register list + detail pages (T-1283 B3)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-18T15:05:18Z
last_update: 2026-04-18T15:38:29Z
date_finished: 2026-04-18T15:38:29Z
---

# T-1295: Watchtower prompt register list + detail pages (T-1283 B3)

## Context

B3 of T-1283. Watchtower read-only list + detail pages for the prompt
register. Reads `prompts/` directly, parses YAML frontmatter, renders
body with copy-to-clipboard. Composer (create/edit UI) is deferred to B4.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/prompts.py` exists with a Blueprint exposing
      `/prompts` (list) and `/prompts/<path:ref>` (detail) routes
- [x] Blueprint is registered in `web/blueprints/__init__.py`
- [x] `web/templates/prompts_list.html` renders a table (id, qid, kind, name, tags)
- [x] `web/templates/prompt_detail.html` renders frontmatter + body with a
      copy-to-clipboard button
- [x] Detail route accepts slug or qid (both resolve to the same prompt)
- [x] Nav link "Prompts" added to NAV_GROUPS under "Work"
- [x] `tests/web/test_prompts.py` has smoke tests for both routes
      returning 200 and containing expected markers
- [x] `pytest tests/web/test_prompts.py -q` passes

### Human
- [x] [REVIEW] List and detail pages look correct in a browser
  **Steps:**
  1. Start Watchtower if not running: `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve`
  2. Open http://localhost:3001/prompts
  3. Click a prompt row to open detail
  4. Click the "Copy" button — verify clipboard contains the body
  **Expected:** List shows all prompts with id and qid; detail shows body; copy works
  **If not:** Note which prompt or button failed and whether the console shows errors

## Verification

test -f web/blueprints/prompts.py
grep -q 'prompts_bp' web/blueprints/__init__.py
test -f web/templates/prompts_list.html
test -f web/templates/prompt_detail.html
grep -q '"Prompts"' web/shared.py
python3 -c "import ast; ast.parse(open('web/blueprints/prompts.py').read())"
test -f tests/web/test_prompts.py
pytest tests/web/test_prompts.py -q

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

### 2026-04-18T15:05:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1295-watchtower-prompt-register-list--detail-.md
- **Context:** Initial task creation

### 2026-04-18T15:38:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-45166e45
- **Timestamp:** 2026-06-02T14:56:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
