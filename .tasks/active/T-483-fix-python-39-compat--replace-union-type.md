---
id: T-483
name: "Fix Python 3.9 compat — replace union type hints (dict | None) with Optional"
description: >
  macOS ships Python 3.9 which lacks PEP 604 union syntax (X | Y). web/shared.py line 159 uses dict | None. Need to find and replace all 3.10+ type hints across web/ with typing.Optional or from __future__ import annotations.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [portability, bugfix]
components: [web/embeddings.py, web/search.py, web/search_utils.py, web/shared.py, web/subprocess_utils.py]
related_tasks: []
created: 2026-03-14T15:01:09Z
last_update: 2026-03-14T15:06:54Z
date_finished: 2026-03-14T15:06:54Z
---

# T-483: Fix Python 3.9 compat — replace union type hints (dict | None) with Optional

## Context

macOS ships Python 3.9 which lacks PEP 604 (`X | Y` union) and PEP 585 (`list[dict]` lowercase generics) at runtime. `from __future__ import annotations` makes all type hints strings (lazy eval), fixing both on 3.9. Related: T-480, T-481.

## Acceptance Criteria

### Agent
- [x] All 13 affected web/*.py files + lib/ask.py have `from __future__ import annotations` as first statement after docstring
- [x] No Python syntax errors across all 44 web/*.py files
- [x] `from __future__` import comes BEFORE all other imports in each file

### Human
- [ ] [RUBBER-STAMP] `fw serve` starts without error on macOS with Python 3.9
  **Steps:**
  1. Run `fw serve` on macOS machine
  2. Open browser to the reported URL
  **Expected:** Watchtower loads without TypeError
  **If not:** Paste the traceback

## Verification

python3 -c "import ast; [ast.parse(open(f).read()) for f in __import__('glob').glob('web/**/*.py', recursive=True)]"
grep -rn "from __future__ import annotations" web/shared.py web/ask.py web/search.py web/embeddings.py | wc -l | grep -q 4

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-14T15:01:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-483-fix-python-39-compat--replace-union-type.md
- **Context:** Initial task creation

### 2026-03-14T15:06:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
