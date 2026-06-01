---
id: T-628
name: "Fix long command line breaks — framework outputs and Human AC steps must be terminal-safe"
description: >
  Recurring issue: framework commands (tier0 approve, inception decide, Human AC steps) produce long lines that break when pasted into terminals. Happened 3+ times with cp+chmod chains. Need structural fix: framework-generated commands must be <80 chars or split into separate lines.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-26T21:33:55Z
last_update: 2026-03-27T18:28:46Z
date_finished: 2026-03-27T18:28:46Z
---

# T-628: Fix long command line breaks — framework outputs and Human AC steps must be terminal-safe

## Context

Framework echo/printf outputs contain 16+ lines >80 chars. These break when pasted in terminals, especially over SSH or narrow panes. 7 files affected: hooks.sh, inception.sh, update-task.sh, check-tier0.sh, check-active-task.sh, bin/fw.

## Acceptance Criteria

### Agent
- [x] No echo/printf line in framework scripts exceeds 80 rendered chars for command suggestions
- [x] Long && chains split into separate numbered steps
- [x] Hooks template in hooks.sh updated (affects new installs)
- [x] Live hooks in .git/hooks/ also updated (affects current repo)

## Verification

# No framework echo lines with command suggestions exceed 80 chars
python3 -c "import subprocess,sys;r=subprocess.run(['grep','-rnE','echo.*\".{81,}\"','-l','agents/','lib/','bin/fw'],capture_output=True,text=True);print(f'Files with long echo: {len(r.stdout.strip().splitlines()) if r.stdout.strip() else 0}')"

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

### 2026-03-26T21:33:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-628-fix-long-command-line-breaks--framework-.md
- **Context:** Initial task creation

### 2026-03-27T17:34:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-03-27T18:28:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
