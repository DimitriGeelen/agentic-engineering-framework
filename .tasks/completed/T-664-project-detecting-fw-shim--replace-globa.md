---
id: T-664
name: "Project-detecting fw shim — replace global install symlink"
description: >
  Phase 2 of T-662: Create bin/fw-shim that walks up from CWD to find project-local fw. Replace install.sh symlink creation with shim installation. Add fw install --shim command. Related: T-662, T-663.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [T-662, isolation, shim]
components: []
related_tasks: []
created: 2026-03-28T17:11:52Z
last_update: 2026-04-06T22:29:20Z
date_finished: 2026-03-28T17:14:19Z
---

# T-664: Project-detecting fw shim — replace global install symlink

## Context

Phase 2 of T-662 (GO). Create a lightweight shim script that replaces the symlink to the global install. The shim walks up from CWD to find the project-local `bin/fw` or `.agentic-framework/bin/fw` and execs it. Also update `install.sh` to install the shim instead of cloning to `$HOME/.agentic-framework/`. Research: `docs/reports/T-662-eliminate-global-install.md`.

## Acceptance Criteria

### Agent
- [x] `bin/fw-shim` exists and walks up from CWD to find project-local fw
- [x] Shim correctly finds `bin/fw` (framework repo) and `.agentic-framework/bin/fw` (consumer)
- [x] Shim prints clear error when no framework project found
- [x] `install.sh` installs the shim to `~/.local/bin/fw` instead of symlinking to global clone
- [x] `install.sh` still clones the framework repo (needed for `fw init` from any directory)
- [x] Existing `claude-fw` wrapper continues to work (still symlinked)

### Human
- [x] [RUBBER-STAMP] Run `fw version` from a consumer project directory — shows consumer's version
  **Steps:**
  1. `cd /opt/001-sprechloop && fw version`
  2. `cd /opt/999-Agentic-Engineering-Framework && fw version`
  **Expected:** Each shows its own version, not the global install's version
  **If not:** Check `which fw` and verify it's the shim

## Verification

test -x bin/fw-shim
grep -q 'exec "$fw_path"' bin/fw-shim
grep -q 'fw-shim' install.sh

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

### 2026-03-28T17:11:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-664-project-detecting-fw-shim--replace-globa.md
- **Context:** Initial task creation

### 2026-03-28T17:14:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next
