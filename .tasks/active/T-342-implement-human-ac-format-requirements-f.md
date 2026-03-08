---
id: T-342
name: "Implement human AC format requirements from T-325"
description: >
  Implement human AC format requirements from T-325

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-08T09:43:49Z
last_update: 2026-03-08T09:43:49Z
date_finished: null
---

# T-342: Implement human AC format requirements from T-325

## Context

Implements GO decision from T-325 inception. See `docs/reports/T-325-human-ac-handoff-quality.md`.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md has "Human AC Format Requirements" section with Steps/Expected/If-not rules
- [x] Task template `.tasks/templates/default.md` has actionable Human AC guidance
- [x] `update-task.sh` emits WARN when human ACs lack Steps blocks at partial-complete

## Verification

grep -q "Human AC Format Requirements" CLAUDE.md
grep -q "Steps:" .tasks/templates/default.md
grep -q "Steps" agents/task-create/update-task.sh

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

### 2026-03-08T09:43:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-342-implement-human-ac-format-requirements-f.md
- **Context:** Initial task creation
