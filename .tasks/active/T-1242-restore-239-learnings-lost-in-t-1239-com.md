---
id: T-1242
name: "Restore 239 learnings lost in T-1239 commit — learnings.yaml overwritten"
description: >
  Restore 239 learnings lost in T-1239 commit — learnings.yaml overwritten

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T20:17:44Z
last_update: 2026-04-13T20:17:44Z
date_finished: null
---

# T-1242: Restore 239 learnings lost in T-1239 commit — learnings.yaml overwritten

## Context

Commit 5d90f655 (T-1239 completion) overwrote learnings.yaml from 239→3 entries.
Restored from ea1e41af (last good state). Root cause: add-learning rewrites entire file.

## Acceptance Criteria

### Agent
- [x] learnings.yaml restored to >= 239 entries
- [x] Bugfix-learning audit check passes

## Verification

python3 -c "import yaml; d=yaml.safe_load(open('.context/project/learnings.yaml')); n=len(d.get('learnings',[])); print(f'{n} learnings'); exit(0 if n >= 239 else 1)"

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

### 2026-04-13T20:17:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1242-restore-239-learnings-lost-in-t-1239-com.md
- **Context:** Initial task creation
