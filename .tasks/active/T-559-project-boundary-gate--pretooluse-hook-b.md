---
id: T-559
name: "Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT"
description: >
  Structural enforcement: PreToolUse hook that blocks Write and Edit tool calls targeting file paths outside PROJECT_ROOT. Also detect Bash commands that cd or write to paths outside PROJECT_ROOT. Triggered by T-549 violation where agent created 6 tasks on another project without authorization.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:53:09Z
last_update: 2026-03-23T16:53:09Z
date_finished: null
---

# T-559: Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT

## Context

Agent created 6 inception tasks on `/opt/openclaw-evaluation/` while working from `/opt/999-Agentic-Engineering-Framework`. No structural gate existed to prevent cross-project writes. Origin: T-549 session violation.

## Acceptance Criteria

### Agent
- [ ] `check-project-boundary.sh` exists in `agents/context/` and is executable
- [ ] Write/Edit to paths outside PROJECT_ROOT is blocked (except /tmp, /root/.claude)
- [ ] Bash commands with `cd /outside-path && ...` write patterns are blocked
- [ ] Hook registered in `.claude/settings.json` on `Write|Edit|Bash` matcher
- [ ] Hook registered in `fw hook` dispatch (bin/fw hook case)
- [ ] Self-test: `echo '{"tool_name":"Write","tool_input":{"file_path":"/opt/other-project/file.txt"}}' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework agents/context/check-project-boundary.sh` exits 2
- [ ] Self-test: `echo '{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/test.txt"}}' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework agents/context/check-project-boundary.sh` exits 0
- [ ] Self-test: `echo '{"tool_name":"Bash","tool_input":{"command":"cd /opt/openclaw-evaluation && fw task create --name test"}}' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework agents/context/check-project-boundary.sh` exits 2

### Human
- [ ] [RUBBER-STAMP] Restart Claude Code session and verify hook fires on cross-project write attempt
  **Steps:**
  1. Restart Claude Code in `/opt/999-Agentic-Engineering-Framework`
  2. Ask agent to write a file to `/opt/openclaw-evaluation/test.txt`
  3. Verify the hook blocks with "PROJECT BOUNDARY BLOCK" message
  **Expected:** Write is blocked, agent sees boundary error
  **If not:** Check `fw doctor` hook validation output

## Verification

test -x agents/context/check-project-boundary.sh
echo '{"tool_name":"Write","tool_input":{"file_path":"/opt/other-project/file.txt"}}' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework agents/context/check-project-boundary.sh 2>/dev/null; test $? -eq 2
echo '{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/test.txt"}}' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework agents/context/check-project-boundary.sh 2>/dev/null; test $? -eq 0
echo '{"tool_name":"Bash","tool_input":{"command":"cd /opt/openclaw-evaluation && fw task create --name test"}}' | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework agents/context/check-project-boundary.sh 2>/dev/null; test $? -eq 2
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
