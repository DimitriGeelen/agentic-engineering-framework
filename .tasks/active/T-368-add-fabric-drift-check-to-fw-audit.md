---
id: T-368
name: "Add fabric drift check to fw audit"
description: >
  In agents/audit/audit.sh, add a check that runs fw fabric drift and warns if unregistered source files exist matching watch patterns. Severity: warning not failure. Closes the feedback loop so empty fabric is surfaced during routine audits. See R-2 in fabric silent-degradation analysis.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [fabric, audit]
components: []
related_tasks: []
created: 2026-03-08T22:27:38Z
last_update: 2026-03-08T22:30:33Z
date_finished: null
---

# T-368: Add fabric drift check to fw audit

## Context

R-2 from fabric silent-degradation analysis. Adds fabric drift detection to the structure section of fw audit.

## Acceptance Criteria

### Agent
- [x] Drift check added to structure section of audit.sh
- [x] Uses watch-patterns.yaml to find unregistered files
- [x] Severity is warn (not fail)
- [x] Gracefully skips if no watch-patterns.yaml exists

## Verification

grep -q "Fabric drift" agents/audit/audit.sh
grep -q "watch-patterns.yaml" agents/audit/audit.sh

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

### 2026-03-08T22:27:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-368-add-fabric-drift-check-to-fw-audit.md
- **Context:** Initial task creation

### 2026-03-08T22:30:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
