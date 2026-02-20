---
id: T-219
name: "Fix fabric page subsystem cards layout — 12 cards crammed into single row"
description: >
  Fix fabric page subsystem cards layout — 12 cards crammed into single row

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-20T09:12:13Z
last_update: 2026-02-20T09:15:53Z
date_finished: 2026-02-20T09:13:51Z
---

# T-219: Fix fabric page subsystem cards layout — 12 cards crammed into single row

## Context

Pico CSS `.grid` class creates equal columns for all children — 12 subsystem cards = 12 columns = text wrapping letter-by-letter. Replaced with explicit CSS grid `repeat(3, 1fr)`.

## Acceptance Criteria

### Agent
- [x] Subsystem cards render in 3-column grid instead of 12-column
- [x] Card names, descriptions, and topology lines are readable
- [x] /fabric page loads without errors

### Human
- [x] Card layout looks clean and readable

## Verification

python3 -c "import urllib.request; r=urllib.request.urlopen('http://localhost:3000/fabric'); assert b'grid-template-columns' in r.read()"

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

### 2026-02-20T09:12:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-219-fix-fabric-page-subsystem-cards-layout--.md
- **Context:** Initial task creation

### 2026-02-20T09:13:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
