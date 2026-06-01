---
id: T-650
name: "Bash task gate — safe-command allowlist + write-pattern detection in check-active-task.sh"
description: >
  T-630 GO build task 1: Add Bash to check-active-task.sh PreToolUse matcher. Implement safe-command allowlist (27 patterns, 6 categories), write-pattern detection, FW_SAFE_MODE escape hatch. ~28 lines added to check-active-task.sh + new lib/safe-commands.sh (~80 lines). Evidence: 7920 Bash invocations analyzed, <0.5% FP rate. Related: T-630, T-619.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-28T09:39:20Z
last_update: 2026-04-06T22:29:19Z
date_finished: 2026-03-28T09:44:32Z
---

# T-650: Bash task gate — safe-command allowlist + write-pattern detection in check-active-task.sh

## Context

T-630 GO: Universal task gate. Design: `docs/reports/T-630-universal-task-gate.md`. This task implements the Bash gating path only.

## Acceptance Criteria

### Agent
- [x] `agents/context/lib/safe-commands.sh` exists with `is_bash_safe_command()` function
- [x] Safe-command allowlist covers 6 categories (git read-only, file reading, searching, fw diagnostics, system, validation)
- [x] `check-active-task.sh` handles Bash tool: extracts command, checks safe-command allowlist, detects write patterns
- [x] FW_SAFE_MODE escape hatch at top of check-active-task.sh (3 lines)
- [x] `fw hook *` commands always allowed (hooks calling hooks)
- [x] `bash -n` syntax check passes on all modified scripts
- [x] Vendored copy synced to `.agentic-framework/agents/context/`
- [x] Verify Bash gate works in a fresh session (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

bash -n agents/context/lib/safe-commands.sh
bash -n agents/context/check-active-task.sh
test -f agents/context/lib/safe-commands.sh
grep -q 'is_bash_safe_command' agents/context/check-active-task.sh
grep -q 'FW_SAFE_MODE' agents/context/check-active-task.sh
test -f agents/context/check-active-task.sh

## Decisions

### 2026-03-28 — Write-pattern check ordering
- **Chose:** Check write patterns BEFORE safe-command allowlist
- **Why:** `cat <<EOF > file` has `cat` in safe list but is a write operation. Write-pattern detection must take priority.
- **Rejected:** Check safe first, then write — would miss redirected safe commands

### Activation Required (B-005)
The code is built, but `.claude/settings.json` needs the matcher updated from `Write|Edit` to `Write|Edit|Bash` for `check-active-task`. This is blocked by B-005 (settings.json protection). The human must update the matcher manually:

```json
{"matcher": "Write|Edit|Bash", "hooks": [{"type": "command", "command": "fw hook check-active-task"}]}
```

## Updates

### 2026-03-28T09:39:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-650-bash-task-gate--safe-command-allowlist--.md
- **Context:** Initial task creation

### 2026-03-28T09:44:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next
