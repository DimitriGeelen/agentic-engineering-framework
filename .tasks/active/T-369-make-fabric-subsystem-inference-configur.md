---
id: T-369
name: "Make fabric subsystem inference configurable"
description: >
  Add .fabric/subsystem-rules.yaml support so non-framework projects can define type/subsystem inference rules. register.sh checks this file BEFORE the hardcoded case statement, falls through to existing patterns if no rules file. See R-3 in fabric silent-degradation analysis.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [fabric, portability]
components: []
related_tasks: []
created: 2026-03-08T22:27:49Z
last_update: 2026-03-08T22:34:14Z
date_finished: null
---

# T-369: Make fabric subsystem inference configurable

## Context

R-3 from fabric silent-degradation analysis. register.sh type/subsystem inference is hardcoded to framework paths.

## Acceptance Criteria

### Agent
- [x] register.sh checks .fabric/subsystem-rules.yaml BEFORE hardcoded case statements
- [x] Rules use fnmatch patterns with type and subsystem fields
- [x] Falls through to existing inference if no rules file or no match
- [x] Shell syntax validates

## Verification

grep -q "subsystem-rules.yaml" agents/fabric/lib/register.sh
bash -n agents/fabric/lib/register.sh

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

### 2026-03-08T22:27:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-369-make-fabric-subsystem-inference-configur.md
- **Context:** Initial task creation

### 2026-03-08T22:34:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
