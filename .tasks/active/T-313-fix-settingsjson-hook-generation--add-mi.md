---
id: T-313
name: "Fix settings.json hook generation — add missing 5 hooks"
description: >
  Consumer projects get 5 of 10 hooks at init time. Missing: budget-gate, block-plan-mode, pre-compact, check-dispatch, resume SessionStart matcher. Update generate_claude_code_config() in lib/init.sh to emit all hooks. Source: T-306 investigation, Agent 4 findings.

status: started-work
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-04T19:27:05Z
last_update: 2026-03-04T20:28:44Z
date_finished: null
---

# T-313: Fix settings.json hook generation — add missing 5 hooks

## Context

T-306 inception found consumer projects get 5 of 10 hooks at init time. Missing: PreCompact (pre-compact.sh), SessionStart/resume, PreToolUse/EnterPlanMode (block-plan-mode.sh), PreToolUse/budget-gate.sh, PostToolUse/check-dispatch.sh. Fix: update `generate_claude_code_config()` in `lib/init.sh`.

## Acceptance Criteria

### Agent
- [x] `generate_claude_code_config()` emits all 10 hooks matching framework's own settings.json
- [x] Generated JSON is valid (parseable by python3 json module)
- [x] Hook order matches framework: PreCompact, SessionStart, PreToolUse, PostToolUse
- [x] PROJECT_ROOT set for hooks that need it (budget-gate, pre-compact, checkpoint, task-gate, tier0, resume)
- [x] Hooks that don't need PROJECT_ROOT omit it (block-plan-mode, error-watchdog, check-dispatch)

## Verification

# Generated JSON template in init.sh is valid
python3 -c "import json, re; content=open('lib/init.sh').read(); start=content.index(\"<< 'SJSON'\") + len(\"<< 'SJSON'\") + 1; end=content.index('\nSJSON', start); data=json.loads(content[start:end]); hooks=sum(len(v) for v in data['hooks'].values()); assert hooks == 10, f'Expected 10 hooks, got {hooks}'"
# All 5 missing hooks now present
grep -q 'budget-gate.sh' lib/init.sh
grep -q 'block-plan-mode.sh' lib/init.sh
grep -q 'pre-compact.sh' lib/init.sh
grep -q 'check-dispatch.sh' lib/init.sh
grep -c 'post-compact-resume.sh' lib/init.sh | grep -q '2'

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

### 2026-03-04T19:27:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-313-fix-settingsjson-hook-generation--add-mi.md
- **Context:** Initial task creation

### 2026-03-04T20:28:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
