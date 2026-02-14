---
id: T-045
name: Web UI foundation: Flask + htmx + fw serve
description: >
  Set up the web UI project structure. Python Flask backend, htmx (single 14kb JS file) for interactivity, server-rendered HTML. Add fw serve command to bin/fw that starts local server on localhost:3000. Basic layout with navigation matching the page set: Dashboard, Project, Directives, Timeline, Tasks, Decisions, Learnings, Gaps, Search. No page content yet — just skeleton with nav and routing. Design authority: 025-ArtifactDiscovery.md. Relevant sections: Technology Decision (Python + htmx), Four-Layer Architecture, Web UI Pages (full set), Architecture diagram.
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:34:04Z
last_update: 2026-02-14T12:27:34Z
date_finished: 2026-02-14T12:27:34Z
---

# T-045: Web UI foundation: Flask + htmx + fw serve

## Design Record

**Design authority:** [025-ArtifactDiscovery.md](../../025-ArtifactDiscovery.md)
**Relevant sections:** Technology Decision (Python + htmx), Four-Layer Architecture, Web UI Pages (full set)

**Key decisions:**
- Python Flask backend, server-rendered HTML
- htmx (single 14kb JS file) for interactivity — no build step, no npm
- `fw serve` starts local server on localhost:3000, binds 127.0.0.1 only
- Navigation matches full page set: Dashboard, Project, Directives, Timeline, Tasks, Decisions, Learnings, Gaps, Search
- Files are the source of truth — no separate database
- All YAML parsing in Python, HTML rendering server-side
- htmx partial pattern: check `HX-Request` header to return fragment vs full page
- Minimal CSS: Pico CSS or similar classless framework (single CSS file, vendored)
- Browser refresh is the update mechanism (no WebSocket, no polling)

**Dependencies (pinned):**
- Flask 3.x, PyYAML 6.x, ruamel.yaml 0.18+, markdown2 (latest), bleach (latest)
- htmx 2.x (vendored JS file), Pico CSS (vendored CSS file)
- Install: `pip install flask pyyaml ruamel.yaml markdown2 bleach`

## Specification Record

### Acceptance Criteria
- [ ] `fw serve` command added to bin/fw, starts Flask server
- [ ] Server binds 127.0.0.1:3000 (configurable port via --port flag)
- [ ] htmx.min.js and Pico CSS served as vendored static assets
- [ ] Base HTML template with navigation to all pages
- [ ] htmx partial rendering: `HX-Request` header check returns fragment vs full page
- [ ] CSRF token generation and validation on write endpoints
- [ ] Each route returns a placeholder page with correct title
- [ ] Clean shutdown on Ctrl-C
- [ ] Startup message shows URL to open in browser
- [ ] Graceful handling if port is already in use
- [ ] Dependencies: Flask, PyYAML, ruamel.yaml, markdown2, bleach (pip-installable)
- [ ] Project structure: `web/` directory with app.py, templates/, static/

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T11:34:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-045-web-ui-foundation-flask--htmx--fw-serve.md
- **Context:** Initial task creation

### 2026-02-14T12:27:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-14T12:27:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
