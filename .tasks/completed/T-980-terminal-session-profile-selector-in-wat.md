---
id: T-980
name: "Terminal session profile selector in Watchtower UI"
description: >
  Add session type selector to /terminal page using the profile data from /api/sessions/profiles. Users can choose between Bash, Zsh, Claude Code, or Dispatch when creating new sessions.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [tests/playwright/test_terminal.py, web/templates/terminal.html]
related_tasks: []
created: 2026-04-06T22:40:09Z
last_update: 2026-04-13T06:28:11Z
date_finished: 2026-04-06T22:43:16Z
---

# T-980: Terminal session profile selector in Watchtower UI

## Context

T-967 added session profiles and `/api/sessions/profiles` API. The terminal page needs a UI to select profiles when creating new sessions. Currently the "New" button creates a plain shell -- it should offer a dropdown/dialog to pick from available profiles.

## Acceptance Criteria

### Agent
- [x] Terminal template updated: "New" button shows profile selector dropdown
- [x] Profile selector fetches from `/api/sessions/profiles` on page load
- [x] Each profile shows name, icon/color, and description
- [x] Selecting a profile creates a session via `createSession(profileId)`
- [x] Terminal page loads without JS errors after changes (8/8 Playwright tests pass)
- [x] Playwright test: profile selector is visible on terminal page (`test_terminal_has_profile_menu`)

### Human
- [x] [REVIEW] Profile selector UI is clean and intuitive
  **Steps:**
  1. Open http://localhost:3000/terminal in browser
  2. Click "New" or the profile dropdown
  3. Verify profiles are listed with labels and colors
  4. Select "Bash" and verify terminal spawns
  **Expected:** Clean dropdown with 4 profiles, session spawns on selection
  **If not:** Screenshot the issue

## Verification

curl -sf http://localhost:3000/terminal | grep -q 'profile'
python3 -m pytest tests/playwright/test_terminal.py -v

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

### 2026-04-06T22:40:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-980-terminal-session-profile-selector-in-wat.md
- **Context:** Initial task creation

### 2026-04-06T22:43:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:27:25Z — status-update [task-update-agent]
- **Change:** horizon: now → next
