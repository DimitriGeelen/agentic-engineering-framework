---
id: T-371
name: "PostToolUse reminder for new source files without fabric cards"
description: >
  Add advisory check (not blocking) that when a NEW file is created matching watch-patterns.yaml globs, emits: NOTE: New source file created. Consider: fw fabric register <path>. Closes feedback loop so agents know registration is expected. See R-5 in fabric silent-degradation analysis.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [fabric, hooks]
components: []
related_tasks: []
created: 2026-03-08T22:28:11Z
last_update: 2026-03-08T22:57:09Z
date_finished: 2026-03-08T22:57:09Z
---

# T-371: PostToolUse reminder for new source files without fabric cards

## Context

R-5 from fabric silent-degradation analysis. Advisory PostToolUse hook that reminds agents to register new source files.

## Acceptance Criteria

### Agent
- [x] Hook script created at agents/context/check-fabric-new-file.sh
- [x] Script checks Write tool output against watch-patterns.yaml
- [x] Skips framework internals (.context/, .tasks/, .fabric/, .claude/)
- [x] Skips files that already have a fabric card
- [x] Advisory only (exit 0 always)

### Human
- [ ] [RUBBER-STAMP] Register hook in settings.json
  **Steps:**
  1. Add to PostToolUse section of `.claude/settings.json`:
     ```json
     {
       "matcher": "Write",
       "hooks": [{ "type": "command", "command": "/opt/999-Agentic-Engineering-Framework/agents/context/check-fabric-new-file.sh" }]
     }
     ```
  2. Restart Claude Code session for hooks to take effect
  **Expected:** When writing a new .py/.sh file, see "NOTE: New source file created. Consider: fw fabric register <path>"
  **If not:** Check `echo '{"tool_name":"Write","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/test.py"}}' | agents/context/check-fabric-new-file.sh`

## Verification

test -x agents/context/check-fabric-new-file.sh
grep -q "watch-patterns.yaml" agents/context/check-fabric-new-file.sh
grep -q "additionalContext" agents/context/check-fabric-new-file.sh

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

### 2026-03-08T22:28:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-371-posttooluse-reminder-for-new-source-file.md
- **Context:** Initial task creation

### 2026-03-08T22:35:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T22:57:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
