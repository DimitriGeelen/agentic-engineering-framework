---
id: T-863
name: "Fix hook lockout — bin/fw hook runner should not require -x on agent scripts"
description: >
  Fix hook lockout — bin/fw hook runner should not require -x on agent scripts

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-04T20:33:21Z
last_update: 2026-04-04T20:36:02Z
date_finished: 2026-04-04T20:36:02Z
---

# T-863: Fix hook lockout — bin/fw hook runner should not require -x on agent scripts

## Context

Failed `git pull --rebase` dropped execute bits on agent scripts. With `core.filemode=false`, Git doesn't restore `+x`. The hook runner in `bin/fw` checks `[ ! -x "$_hook_script" ]` and exits 2, creating a complete lockout where no Bash/Write/Edit works. Fix: use `bash "$_hook_script"` instead of requiring execute permission.

## Acceptance Criteria

### Agent
- [x] Hook runner uses `bash "$_hook_script"` instead of requiring `-x`
- [x] Check changed from `-x` to `-f` (file exists, not executable)
- [x] Hooks still work normally after the change (verified: fw version, hook calls work)

## Verification

grep -q 'bash.*_hook_script' bin/fw
# Verify -x check removed
! grep -q '\[ ! -x "\$_hook_script" \]' bin/fw

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

### 2026-04-04T20:33:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-863-fix-hook-lockout--binfw-hook-runner-shou.md
- **Context:** Initial task creation

### 2026-04-04T20:36:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8713d0d7
- **Timestamp:** 2026-06-02T15:05:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
