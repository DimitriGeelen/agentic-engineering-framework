---
id: T-486
name: "Watchtower smoke test: runtime route discovery + content markers + fw doctor integration"
description: >
  Build from T-485 inception GO. Phase 1+2: Create web/smoke_test.py that auto-discovers routes via Flask url_map, tests each for 200, checks content markers on critical routes. Integrate into fw doctor and fw audit deployment section.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, testing, reliability]
components: []
related_tasks: []
created: 2026-03-14T15:34:18Z
last_update: 2026-03-14T15:34:18Z
date_finished: null
---

# T-486: Watchtower smoke test: runtime route discovery + content markers + fw doctor integration

## Context

From T-485 inception GO. 69 endpoints across 18 blueprints need smoke testing. See docs/reports/T-485-watchtower-smoke-test-inception.md for full research.

## Acceptance Criteria

### Agent
- [x] `web/smoke_test.py` exists and auto-discovers routes via Flask `url_map`
- [x] All parameterless GET routes tested for HTTP 200 (28/28 pass)
- [x] Critical routes (/, /tasks, /search, /fabric, /quality, /settings) have content marker checks
- [x] Script returns JSON summary: `{"passed": N, "failed": N, "errors": [...]}`
- [x] `fw doctor` includes "Watchtower endpoints" section when server is running
- [x] Script runnable standalone: `python3 web/smoke_test.py [--port 3000]`
- [x] All web/*.py files pass syntax check

### Human
- [ ] [RUBBER-STAMP] Run `fw doctor` with Watchtower running — smoke section appears
  **Steps:**
  1. Start Watchtower: `fw serve`
  2. In another terminal: `fw doctor`
  **Expected:** Doctor output includes "Watchtower endpoints" section with OK/WARN per route
  **If not:** Paste the doctor output

## Verification

python3 -c "import ast; ast.parse(open('web/smoke_test.py').read())"
python3 -c "from web.smoke_test import run_smoke_tests; print('importable')"
grep -q 'url_map' web/smoke_test.py

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

### 2026-03-14T15:34:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-486-watchtower-smoke-test-runtime-route-disc.md
- **Context:** Initial task creation
