---
id: T-370
name: "Document depends_on edge format in fabric skeleton card"
description: >
  Update skeleton card template in agents/fabric/lib/register.sh to include edge format hint: {target: <path>, type: calls|reads|writes|triggers|renders}. Without this, agents write plain string lists which traverse.sh silently ignores. See R-4 in fabric silent-degradation analysis.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [fabric, documentation]
components: []
related_tasks: []
created: 2026-03-08T22:27:59Z
last_update: 2026-03-08T22:28:47Z
date_finished: null
---

# T-370: Document depends_on edge format in fabric skeleton card

## Context

R-4 from fabric silent-degradation analysis. traverse.sh expects `{target: path, type: calls}` edges but the skeleton card shows bare `depends_on: []` with no format hint.

## Acceptance Criteria

### Agent
- [x] Skeleton card template includes depends_on format comment with target/type fields
- [x] Skeleton card template includes depended_by section
- [x] Fill-in hint mentions edge format

## Verification

grep -q "target:" agents/fabric/lib/register.sh
grep -q "calls|reads|writes|triggers|renders" agents/fabric/lib/register.sh
grep -q "depended_by" agents/fabric/lib/register.sh

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

### 2026-03-08T22:27:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-370-document-dependson-edge-format-in-fabric.md
- **Context:** Initial task creation

### 2026-03-08T22:28:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
