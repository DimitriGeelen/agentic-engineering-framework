---
id: T-1199
name: "Fix config-registry-parity — add CONSUMER_SCAN_DIRS to web/blueprints/config.py"
description: >
  Fix config-registry-parity — add CONSUMER_SCAN_DIRS to web/blueprints/config.py

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/blueprints/config.py]
related_tasks: []
created: 2026-04-13T07:23:56Z
last_update: 2026-04-13T07:25:38Z
date_finished: 2026-04-13T07:25:38Z
---

# T-1199: Fix config-registry-parity — add CONSUMER_SCAN_DIRS to web/blueprints/config.py

## Context

T-1195 added FW_CONSUMER_SCAN_DIRS to lib/config.sh but not to web/blueprints/config.py. Invariant test `config-registry-parity.bats` caught it.

## Acceptance Criteria

### Agent
- [x] CONSUMER_SCAN_DIRS added to web/blueprints/config.py SETTINGS
- [x] config-registry-parity lint tests pass

## Verification

bats tests/lint/config-registry-parity.bats
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-13T07:23:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1199-fix-config-registry-parity--add-consumer.md
- **Context:** Initial task creation

### 2026-04-13T07:25:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
