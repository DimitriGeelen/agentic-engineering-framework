---
id: T-353
name: "Fix related_tasks per-character link rendering in Watchtower"
description: >
  Fix related_tasks per-character link rendering in Watchtower

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [web/templates/task_detail.html]
related_tasks: []
created: 2026-03-08T16:59:40Z
last_update: 2026-03-08T17:19:59Z
date_finished: 2026-03-08T17:19:59Z
---

# T-353: Fix related_tasks per-character link rendering in Watchtower

## Context

Watchtower task detail page rendered `related_tasks.parent` as per-character links when the episodic YAML had a string value instead of a list. Jinja iterates over strings character by character. Fixed template to handle both types; fixed 3 episodic files (T-076, T-081, T-082).

## Acceptance Criteria

### Agent
- [x] Template handles string values in related_tasks without per-character links
- [x] Template handles list values in related_tasks (existing behavior preserved)
- [x] Episodic files T-076, T-081, T-082 converted from string to list format

## Verification

# Template renders T-076 related tasks as single link
curl -sf http://localhost:3000/tasks/T-076 | grep -q 'href="/tasks/T-072"'
# Episodic files have list format
grep -q 'parent: \["T-072"\]' .context/episodic/T-076.yaml

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

### 2026-03-08T16:59:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-353-fix-relatedtasks-per-character-link-rend.md
- **Context:** Initial task creation

### 2026-03-08T17:19:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
