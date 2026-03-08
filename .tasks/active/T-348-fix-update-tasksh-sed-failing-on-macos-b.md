---
id: T-348
name: "Fix update-task.sh sed failing on macOS BSD sed"
description: >
  update-task.sh uses sed -i without BSD compat. Same class as L-081.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [cli, macos, portability]
components: [C-001, agents/context/lib/decision.sh, agents/context/lib/focus.sh, C-002, agents/context/lib/pattern.sh, agents/git/git.sh, agents/git/lib/common.sh, agents/observe/observe.sh, agents/resume/resume.sh, agents/task-create/update-task.sh, bin/fw, lib/init.sh, lib/setup.sh, lib/upgrade.sh]
related_tasks: []
created: 2026-03-08T12:34:08Z
last_update: 2026-03-08T12:55:20Z
date_finished: 2026-03-08T12:55:20Z
---

# T-348: Fix update-task.sh sed failing on macOS BSD sed

## Context

Portable `_sed_i` helper using temp files — works on both GNU sed (Linux) and BSD sed (macOS). Replaces all `sed -i` calls across 12 files. See L-081.

## Acceptance Criteria

### Agent
- [x] `lib/compat.sh` created with portable `_sed_i()` function
- [x] Zero `sed -i ` calls remain in *.sh files (excluding echo strings)
- [x] `update-task.sh` status transitions work (tested on GNU sed)
- [x] `focus.sh` set-focus works (tested on GNU sed)
- [x] All files that use `_sed_i` source compat.sh or have inline fallback

### Human
- [ ] [RUBBER-STAMP] `fw task update` works on macOS after Homebrew reinstall
  **Steps:**
  1. `brew update && brew reinstall dimitrigeelen/agentic-fw/fw`
  2. `cd` to a test project and run `fw init --force --provider claude`
  3. Run `fw task create --name "test" --type build --owner human --start`
  4. Run `fw task update T-001 --status work-completed --force`
  **Expected:** No sed errors, task moves to completed/
  **If not:** Copy the error output and report

## Verification

# No unprotected sed -i calls (excluding echo strings in resolve.sh)
test "$(grep -r 'sed -i ' --include='*.sh' lib/ agents/ bin/ | grep -v '_sed_i\|echo\|#' | wc -l)" -eq 0
# compat.sh exists and is valid bash
bash -n lib/compat.sh
# update-task.sh loads without syntax errors
bash -n agents/task-create/update-task.sh

## Decisions

### 2026-03-08 — Portable sed approach
- **Chose:** Temp file helper (`_sed_i` in `lib/compat.sh`)
- **Why:** Works on ALL systems without detection logic. Single function, easy to audit.
- **Rejected:** GNU/BSD detection at each callsite (verbose, 20+ if/else blocks); `perl -i -pe` (adds dependency); `sed -i.bak && rm` (leaves temp files on failure)

## Updates

### 2026-03-08T12:34:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-348-fix-update-tasksh-sed-failing-on-macos-b.md
- **Context:** Initial task creation

### 2026-03-08T12:53:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T12:53:48Z — status-update [task-update-agent]
- **Change:** tags: +portability

### 2026-03-08T12:55:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
