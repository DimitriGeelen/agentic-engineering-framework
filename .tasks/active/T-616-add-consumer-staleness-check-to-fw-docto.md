---
id: T-616
name: "Add consumer staleness check to fw doctor"
description: >
  fw doctor is framework-centric, not consumer-aware. Add checks: version drift detection, hook completeness by TYPE, CLAUDE.md governance hash, upgrade timestamp. From T-614 investigation.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [governance, doctor, consumer]
components: []
related_tasks: []
created: 2026-03-25T20:17:21Z
last_update: 2026-03-25T22:17:33Z
date_finished: null
---

# T-616: Add consumer staleness check to fw doctor

## Context

`fw doctor` only checks framework health. T-614 showed all 7 consumers silently decayed. Add consumer fleet scan.

## Acceptance Criteria

### Agent
- [x] `fw doctor` scans /opt for `.framework.yaml` files to discover consumers
- [x] Reports each consumer: name, version, hook count vs framework
- [x] Version mismatch shown as WARN with `fw upgrade <path>` suggestion
- [x] Missing hooks shown as WARN with specific hook names
- [x] Works when no consumers exist (graceful skip)

## Verification

bash -n bin/fw
bin/fw doctor 2>&1 | grep -q 'Consumer'

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

### 2026-03-25T20:17:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-616-add-consumer-staleness-check-to-fw-docto.md
- **Context:** Initial task creation

### 2026-03-25T22:17:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
