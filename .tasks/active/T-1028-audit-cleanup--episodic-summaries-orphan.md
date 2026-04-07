---
id: T-1028
name: "Audit cleanup — episodic summaries, orphaned fabric card"
description: >
  Audit cleanup — episodic summaries, orphaned fabric card

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T13:27:06Z
last_update: 2026-04-07T13:27:06Z
date_finished: null
---

# T-1028: Audit cleanup — episodic summaries, orphaned fabric card

## Context

Audit shows 11 warnings — fix episodic missing for T-1025 and T-1026, clean orphaned fabric card.

## Acceptance Criteria

### Agent
- [x] Episodic summaries generated for T-1025 and T-1026
- [x] Orphaned fabric card removed (web-terminal.yaml → web/terminal.py, refactored to package)

## Verification

ls .context/episodic/T-1025.yaml .context/episodic/T-1026.yaml

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

### 2026-04-07T13:27:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1028-audit-cleanup--episodic-summaries-orphan.md
- **Context:** Initial task creation
