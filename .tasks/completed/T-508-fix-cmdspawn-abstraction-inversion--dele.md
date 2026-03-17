---
id: T-508
name: "Fix cmd_spawn() abstraction inversion — delegate to termlink spawn --wait (GH #9)"
description: >
  Fix cmd_spawn() abstraction inversion — delegate to termlink spawn --wait (GH #9)

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-16T13:40:16Z
last_update: 2026-03-16T13:44:32Z
date_finished: 2026-03-16T13:44:32Z
---

# T-508: Fix cmd_spawn() abstraction inversion — delegate to termlink spawn --wait (GH #9)

## Context

Field bug from worddoclezer project (GitHub issue #9). `cmd_spawn()` in `agents/termlink/termlink.sh` manually reimplements terminal spawning, platform detection, shell init timing, and wait-for-registration that `termlink spawn` already handles natively. Two bugs: shell init race condition (osascript fires before profile loads) and `--tag` vs `--tags` mismatch. Fix: delegate to `termlink spawn --wait` instead of reimplementing.

## Acceptance Criteria

### Agent
- [x] `cmd_spawn()` delegates to `termlink spawn --wait` instead of manual osascript/gnome-terminal
- [x] No `--tag` (singular) in termlink.sh — only `--tags` (plural)
- [x] No manual `osascript` terminal spawning in `cmd_spawn()` — platform detection delegated to binary
- [x] No manual registration polling loop in `cmd_spawn()` — `--wait` flag handles it
- [x] `shellcheck agents/termlink/termlink.sh` passes (pre-existing info-level warnings only)
- [x] Audit of other wrapper functions documented — no other abstraction inversions found
- [x] GitHub issue #9 referenced in commit (38aa95e "fixes #9")

## Verification

# Delegates to termlink spawn
grep -q 'termlink spawn' agents/termlink/termlink.sh
# No manual osascript terminal spawning
test "$(grep -c 'osascript.*do script.*termlink register' agents/termlink/termlink.sh)" = "0"
# No manual gnome-terminal spawning
test "$(grep -c 'gnome-terminal.*termlink register' agents/termlink/termlink.sh)" = "0"

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

### 2026-03-16T13:40:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-508-fix-cmdspawn-abstraction-inversion--dele.md
- **Context:** Initial task creation

### 2026-03-16T13:44:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
