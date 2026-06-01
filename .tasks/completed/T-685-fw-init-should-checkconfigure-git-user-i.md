---
id: T-685
name: "fw init should check/configure git user identity"
description: >
  F-9: fw init does not check or configure git user identity. Fresh environments fail on first governed commit with 'Author identity unknown'. fw doctor could check for this, or fw init could set a default. Discovered during T-679 vnx experiment.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-03-28T22:03:52Z
last_update: 2026-03-28T22:08:55Z
date_finished: 2026-03-28T22:08:55Z
---

# T-685: fw init should check/configure git user identity

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Add git user.email/user.name check to `fw doctor` — WARN if not configured
- [x] Shows fix instructions: `git config user.email/user.name`
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

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

### 2026-03-28T22:03:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-685-fw-init-should-checkconfigure-git-user-i.md
- **Context:** Initial task creation

### 2026-03-28T22:07:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T22:08:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
