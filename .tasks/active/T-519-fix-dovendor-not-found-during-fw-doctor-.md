---
id: T-519
name: "Fix do_vendor not found during fw doctor interactive init"
description: >
  fw doctor interactive init path (lines 100-200 in bin/fw) calls do_init which calls do_vendor, but do_vendor is defined at line 1173 — after the interactive block. Exit 127. Found during TermLink install test.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, install, D2]
components: []
related_tasks: []
created: 2026-03-17T22:38:57Z
last_update: 2026-03-17T22:38:57Z
date_finished: null
---

# T-519: Fix do_vendor not found during fw doctor interactive init

## Context

`fw doctor` interactive init (lines 100-200 in `bin/fw`) sources `lib/init.sh` which calls `do_vendor()`, but `do_vendor` is defined at line 1173 — after the interactive block. Fix: move `do_vendor` before the interactive path, or forward-declare it.

## Acceptance Criteria

### Agent
- [x] `do_vendor` is available when `do_init` is called from the interactive init path
- [x] `bash -n bin/fw` passes

## Verification

bash -n bin/fw
# Verify do_vendor is defined before the interactive init block
grep -n "do_vendor()" bin/fw | head -1 | awk -F: '{exit ($1 > 100)}'

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

### 2026-03-17T22:38:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-519-fix-dovendor-not-found-during-fw-doctor-.md
- **Context:** Initial task creation
