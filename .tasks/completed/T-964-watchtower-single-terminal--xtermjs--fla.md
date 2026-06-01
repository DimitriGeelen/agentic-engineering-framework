---
id: T-964
name: "Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)"
description: >
  Phase 1 of web terminal: Add Flask-SocketIO WebSocket support to Watchtower, embed xterm.js in a /terminal page, implement PTY manager for single terminal session. Includes: pip dependency (flask-socketio, eventlet), xterm.js CDN or vendored JS, WebSocket route for PTY I/O, basic terminal page with PicoCSS styling. From T-962 GO.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T18:25:12Z
last_update: 2026-04-06T19:13:20Z
date_finished: 2026-04-06T18:59:03Z
---

# T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)

## Context

Phase 1 of T-962 web terminal. See `docs/reports/T-962-web-terminal-research.md` for full research. Architecture: xterm.js frontend + Flask-SocketIO WebSocket transport + custom PTY manager.

## Acceptance Criteria

### Agent
- [x] Flask-SocketIO dependency added and working
- [x] `/terminal` page renders with xterm.js terminal
- [x] WebSocket PTY bridge pipes keystrokes to shell and output to browser
- [x] Terminal resizes correctly on browser window resize
- [x] Navigation link added to Watchtower sidebar (Architecture group)
- [x] Terminal page styled with PicoCSS dark theme (VS Code color scheme)

### Human
- [x] [REVIEW] Terminal is interactive and responsive
  **Steps:**
  1. Open http://localhost:3000/terminal in browser
  2. Type `ls`, `pwd`, `echo hello` — verify output appears
  3. Try colors: `ls --color=auto`
  4. Try resize: drag browser window
  **Expected:** Responsive interactive terminal with proper colors and resize
  **If not:** Note specific issues (latency, missing colors, resize broken)

## Verification

# Terminal page returns 200
python3 -c "from web.app import app; c=app.test_client(); r=c.get('/terminal'); exit(0 if r.status_code==200 else 1)"
# xterm.js is referenced in template
grep -q 'xterm' web/templates/terminal.html
# Flask-SocketIO is importable
python3 -c "import flask_socketio"
# Terminal blueprint registered
grep -q 'terminal' web/app.py

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

### 2026-04-06T18:25:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-964-watchtower-single-terminal--xtermjs--fla.md
- **Context:** Initial task creation

### 2026-04-06T18:26:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T18:59:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
