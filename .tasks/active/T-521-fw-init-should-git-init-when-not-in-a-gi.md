---
id: T-521
name: "fw init should git init when not in a git repo"
description: >
  fw init doesn't create a git repo. Git hooks, traceability, and commit-msg enforcement all require git. Should git init + initial commit if not already in a repo. Found during TermLink install test.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [enhancement, install, D3]
components: []
related_tasks: []
created: 2026-03-17T22:39:15Z
last_update: 2026-03-17T22:39:15Z
date_finished: null
---

# T-521: fw init should git init when not in a git repo

## Context

`fw init` should auto-create a git repo if not already in one. Git is required for hooks, traceability, and commit-msg enforcement.

## Acceptance Criteria

### Agent
- [x] `lib/init.sh` calls `git init` when target is not in a git repo
- [x] `bash -n lib/init.sh` passes

## Verification

bash -n lib/init.sh
grep -q "git init" lib/init.sh

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

### 2026-03-17T22:39:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-521-fw-init-should-git-init-when-not-in-a-gi.md
- **Context:** Initial task creation
