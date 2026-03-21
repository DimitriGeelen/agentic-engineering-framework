---
id: T-509
name: "Harden check-dispatch.sh — promote from advisory to blocking, validate preamble"
description: >
  Promote check-dispatch.sh from PostToolUse advisory to PreToolUse blocking. Validate preamble inclusion in Task tool prompts. Enforce max 5 parallel agents. From T-477 Spike 3, Option A build task 1.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [governance, enforcement, D2]
components: [bin/fw]
related_tasks: []
created: 2026-03-17T11:33:54Z
last_update: 2026-03-17T11:38:24Z
date_finished: 2026-03-17T11:38:24Z
---

# T-509: Harden check-dispatch.sh — promote from advisory to blocking, validate preamble

## Context

From T-477 inception (governance declaration layer). PostToolUse advisory is insufficient — T-073 (177K spike) happened despite advisory existing. PreToolUse blocking prevents dispatch WITHOUT preamble.

## Acceptance Criteria

### Agent
- [x] PreToolUse hook script `check-dispatch-pre.sh` exists and is executable
- [x] Hook validates preamble markers in Task tool prompt (needs 2 of 3: write, /tmp/fw-agent, summary)
- [x] Explore, Plan, haiku, and resumed agents are exempt from preamble check
- [x] PostToolUse `check-dispatch.sh` still works for response size warnings
- [x] fw hook help text includes new hook name

### Human
- [ ] [RUBBER-STAMP] Add PreToolUse Task hook to `.claude/settings.json`
  **Steps:**
  1. Open `.claude/settings.json`
  2. Add this entry to the `PreToolUse` array (after the budget-gate entry):
     ```json
     {
       "matcher": "Task",
       "hooks": [{ "type": "command", "command": "fw hook check-dispatch-pre" }]
     }
     ```
  3. Restart Claude Code session (hooks snapshot at start)
  **Expected:** `fw hook check-dispatch-pre` blocks Task calls without preamble markers
  **If not:** Run `echo '{"tool_name":"Task","tool_input":{"prompt":"do stuff","subagent_type":"general-purpose"}}' | agents/context/check-dispatch-pre.sh; echo $?` — should exit 2

## Verification

test -x agents/context/check-dispatch-pre.sh
grep -q "check-dispatch-pre" bin/fw

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

### 2026-03-17T11:33:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-509-harden-check-dispatchsh--promote-from-ad.md
- **Context:** Initial task creation

### 2026-03-17T11:38:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
