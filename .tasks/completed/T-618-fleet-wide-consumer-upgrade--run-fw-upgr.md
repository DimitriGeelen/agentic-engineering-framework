---
id: T-618
name: "Fleet-wide consumer upgrade — run fw upgrade on all 7 consumer projects"
description: >
  All 7 consumer projects stuck at v1.2.6 with 11/13 hooks. Missing: check-project-boundary (T-559), commit-cadence (T-591). After T-615 fixes upgrade.sh, run fw upgrade on each consumer. From T-614 investigation.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [governance, upgrade, fleet]
components: []
related_tasks: []
created: 2026-03-25T20:17:26Z
last_update: 2026-03-25T22:17:07Z
date_finished: 2026-03-25T22:17:07Z
---

# T-618: Fleet-wide consumer upgrade — run fw upgrade on all 7 consumer projects

## Context

T-614 found all 7 consumers at v1.2.6, missing 2 hooks. T-615 fixed detection. Now apply `fw upgrade` to all. Uses `fw upgrade <path>` which is a framework command — writes go to consumer dirs.

## Acceptance Criteria

### Agent
- [x] All 7 consumer projects upgraded via `fw upgrade`
- [x] Each project reports 0 missing hooks after upgrade (15/15 hooks each)
- [x] Each project version updated to current framework version (1.3.0)

## Verification

# All consumers at current version
grep -q "version: 1.3.0" /opt/termlink/.framework.yaml
grep -q "version: 1.3.0" /opt/050-email-archive/.framework.yaml
grep -q "version: 1.3.0" /opt/001-sprechloop/.framework.yaml

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

### 2026-03-25T20:17:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-618-fleet-wide-consumer-upgrade--run-fw-upgr.md
- **Context:** Initial task creation

### 2026-03-25T22:17:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
