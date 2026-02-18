---
id: T-146
name: "Fix G-001: fw init generic provider must wire Claude Code hooks"
description: >
  Fix G-001: fw init generic provider must wire Claude Code hooks

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T10:01:46Z
last_update: 2026-02-18T10:02:53Z
date_finished: 2026-02-18T10:02:53Z
---

# T-146: Fix G-001: fw init generic provider must wire Claude Code hooks

## Context

G-001: `fw init --provider generic` (the default) skipped `generate_claude_code_config()`, so new projects got no budget-gate, checkpoint, or error-watchdog hooks. See `.context/inbox/2026-02-18-sprechloop-gap-feedback.md`.

## Acceptance Criteria

- [x] `fw init` (generic provider) generates `.claude/settings.json` with all hooks
- [x] `PROJECT_ROOT` in generated hooks points to project dir, not framework
- [x] Unknown provider fallback also wires hooks

## Verification

# Test that generic provider wires hooks in init.sh
grep -q "generate_claude_code_config" lib/init.sh
# Verify generic case has generate_claude_code_config before its ;;
grep -A3 "generic)" lib/init.sh | grep -q "generate_claude_code_config"

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

### 2026-02-18T10:01:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-146-fix-g-001-fw-init-generic-provider-must-.md
- **Context:** Initial task creation

### 2026-02-18T10:02:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
