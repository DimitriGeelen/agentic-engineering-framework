---
id: T-379
name: "Settings page with engine selector and config persistence"
description: >
  Create web/blueprints/settings.py with routes for settings page. YAML persistence at .context/settings.yaml (gitignored). Engine selector (Ollama/OpenRouter), model picker, API key management UI. Gear icon in nav. Depends on T-377 (LLM provider) and T-378 (key storage). Parent: T-375.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [ui, settings]
components: [web/app.py, web/templates/base.html]
related_tasks: []
created: 2026-03-09T09:41:42Z
last_update: 2026-03-10T22:04:14Z
date_finished: 2026-03-09T09:57:39Z
---

# T-379: Settings page with engine selector and config persistence

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] web/blueprints/settings.py created with routes for page, save, save-key, delete-key, test-connection, models
- [x] web/templates/settings.html with engine selector, API key management, info section
- [x] YAML persistence at .context/settings.yaml (gitignored)
- [x] Gear icon added to nav in base.html
- [x] Blueprint registered in app.py
- [x] Settings page returns 200 with correct content

### Human
- [ ] [RUBBER-STAMP] Settings page looks good and gear icon is visible
  **Steps:**
  1. Open http://localhost:3000/settings/
  2. Verify gear icon appears in top-right nav
  3. Check provider dropdown, model fields, API key section render
  **Expected:** Clean Pico CSS layout with engine selector, model fields, key management
  **If not:** Note which section looks broken

## Verification

curl -sf http://localhost:3000/settings/ | grep -q "LLM Engine"
python3 -c "from web.blueprints.settings import bp; print('OK')"

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

### 2026-03-09T09:41:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-379-settings-page-with-engine-selector-and-c.md
- **Context:** Initial task creation

### 2026-03-09T09:53:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T09:57:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
