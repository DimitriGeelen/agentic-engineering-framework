---
id: T-153
name: "Sync task atomization rule to sprechloop CLAUDE.md"
description: >
  Sync task atomization rule to sprechloop CLAUDE.md

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T12:40:10Z
last_update: 2026-02-18T12:48:56Z
date_finished: 2026-02-18T12:48:56Z
---

# T-153: Sync task atomization rule to sprechloop CLAUDE.md

## Context

Codify L-051 (one bug = one task) and L-052 (register gaps before fixing) into CLAUDE.md across all locations: framework CLAUDE.md, claude-project.md template, and sprechloop CLAUDE.md.

## Acceptance Criteria

- [x] "One bug = one task" rule added to framework CLAUDE.md Task Sizing Rules
- [x] "One bug = one task" rule added to lib/templates/claude-project.md
- [x] "One bug = one task" rule added to sprechloop CLAUDE.md
- [x] "Register first, fix second" protocol added to framework CLAUDE.md Working with Tasks
- [x] "Register first, fix second" protocol added to sprechloop CLAUDE.md Working with Tasks

## Verification

grep -q "One bug = one task" CLAUDE.md
grep -q "One bug = one task" lib/templates/claude-project.md
grep -q "One bug = one task" /opt/001-sprechloop/CLAUDE.md
grep -q "Register first, fix second" CLAUDE.md
grep -q "Register first, fix second" /opt/001-sprechloop/CLAUDE.md

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

### 2026-02-18T12:40:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-153-sync-task-atomization-rule-to-sprechloop.md
- **Context:** Initial task creation

### 2026-02-18T12:48:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
