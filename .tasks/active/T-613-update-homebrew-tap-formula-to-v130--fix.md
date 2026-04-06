---
id: T-613
name: "Update Homebrew tap formula to v1.4.0 + fix consumer project hook errors"
description: >
  Update Homebrew tap formula to v1.4.0 with git-derived versioning, MCP auto-config, and Watchtower approvals

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-25T17:08:35Z
last_update: 2026-04-06T22:29:18Z
date_finished: 2026-03-27T18:04:50Z
---

# T-613: Update Homebrew tap formula to v1.3.0 + fix consumer project hook errors

## Context

Homebrew tap at 1.2.6 while source is at 1.3.0 (470 commits behind). Consumer projects have hook errors because vendored framework is outdated. Related: T-606 (version bump), T-359 (formula rename).

## Acceptance Criteria

### Agent
- [x] v1.3.0 tag pushed to both GitHub and OneDev
- [x] v1.4.0 tag pushed to both GitHub and OneDev
- [x] Homebrew formula updated with v1.4.0 URL and SHA256
- [x] Formula pushed to homebrew-agentic-fw tap repo

### Human
- [ ] [RUBBER-STAMP] Verify brew upgrade works on macOS
  **Steps:**
  1. `brew update && brew upgrade agentic-fw`
  2. `fw version`
  **Expected:** Version shows 1.4.0
  **If not:** Run `brew tap-info dimitrigeelen/agentic-fw` and check HEAD commit

## Verification

grep -q "v1.4.0" /tmp/homebrew-agentic-fw/Formula/agentic-fw.rb

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

### 2026-03-25T17:08:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-613-update-homebrew-tap-formula-to-v130--fix.md
- **Context:** Initial task creation

### 2026-03-27T19:05:00Z — updated to v1.4.0
- **Action:** Updated formula from v1.3.0 to v1.4.0 (T-648 introduced git-derived versioning)
- **v1.4.0 tag pushed:** GitHub + OneDev
- **Formula SHA256:** 81556a9f7bd04bd1aa7fec4f028e705a898a5730f2caee82196b1616a941314f
- **Formula pushed:** homebrew-agentic-fw main (f533eaf)

### 2026-03-27T18:04:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next
