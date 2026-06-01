---
id: T-559
name: "Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT"
description: >
  Structural enforcement: PreToolUse hook that blocks Write and Edit tool calls targeting file paths outside PROJECT_ROOT. Also detect Bash commands that cd or write to paths outside PROJECT_ROOT. Triggered by T-549 violation where agent created 6 tasks on another project without authorization.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:53:09Z
last_update: 2026-03-26T15:47:28Z
date_finished: 2026-03-24T10:57:44Z
---

# T-559: Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT

## Context

Agent created 6 inception tasks on `/opt/openclaw-evaluation/` while working from `/opt/999-Agentic-Engineering-Framework`. No structural gate existed to prevent cross-project writes. Origin: T-549 session violation.

## Acceptance Criteria

### Agent
- [x] `check-project-boundary.sh` exists in `agents/context/` and is executable
- [x] Write/Edit to paths outside PROJECT_ROOT is blocked (except /tmp, /root/.claude)
- [x] Bash commands with `cd /outside-path && ...` write patterns are blocked
- [x] Hook registered in `.claude/settings.json` on `Write|Edit|Bash` matcher
- [x] Hook registered in `fw hook` dispatch (bin/fw hook case)
- [x] Self-test: outside path → exit 2 (verified dynamically to avoid hook self-triggering)
- [x] Self-test: inside path → exit 0 (verified)
- [x] Self-test: cd to other project → exit 2 (verified dynamically)

### Human
- [x] [RUBBER-STAMP] Restart Claude Code session and verify hook fires on cross-project write attempt
  **Steps:**
  1. Restart Claude Code in `/opt/999-Agentic-Engineering-Framework`
  2. Ask agent to write a file to `/opt/openclaw-evaluation/test.txt`
  3. Verify the hook blocks with "PROJECT BOUNDARY BLOCK" message
  **Expected:** Write is blocked, agent sees boundary error
  **If not:** Check `fw doctor` hook validation output

## Verification

test -x agents/context/check-project-boundary.sh
grep -q 'check-project-boundary' .claude/settings.json

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

### 2026-03-23T16:53:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-559-project-boundary-gate--pretooluse-hook-b.md
- **Context:** Initial task creation

### 2026-03-24T10:57:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
