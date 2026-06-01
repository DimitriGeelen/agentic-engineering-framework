---
id: T-875
name: "Fix installer UX — Run: prefix causes copy-paste errors"
description: >
  Fix installer UX — Run: prefix causes copy-paste errors

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-05T05:59:41Z
last_update: 2026-04-13T06:29:06Z
date_finished: 2026-04-05T06:02:11Z
---

# T-875: Fix installer UX — Run: prefix causes copy-paste errors

## Context

install.sh prints `Run: /path/fw doctor` when doctor has warnings. Users copy-paste the whole line including `Run:`, getting "Run:: command not found". Discovered from user install output on 025-WokrshopDesigner.

## Acceptance Criteria

### Agent
- [x] install.sh no longer prints `Run:` prefix before commands
- [x] Suggested commands are clearly copy-pasteable without prefix

### Human
- [x] [RUBBER-STAMP] Installer output shows clean copy-pasteable commands
  **Steps:**
  1. `cd /opt/025-WokrshopDesigner && curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash`
  **Expected:** Doctor warning shows command without `Run:` prefix
  **If not:** Check install.sh line ~286

## Verification

grep -q "To see details" install.sh
! grep -q 'echo.*"  Run:' install.sh

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

### 2026-04-05T05:59:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-875-fix-installer-ux--run-prefix-causes-copy.md
- **Context:** Initial task creation

### 2026-04-05T06:02:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:27:24Z — status-update [task-update-agent]
- **Change:** horizon: now → next
