---
id: T-1155
name: "T-1154 invariant test — single-port-detection lint guard"
description: >
  T-1154 invariant test — single-port-detection lint guard

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T11:45:12Z
last_update: 2026-04-12T11:46:15Z
date_finished: 2026-04-12T11:46:15Z
---

# T-1155: T-1154 invariant test — single-port-detection lint guard

## Context

Invariant test for T-1154. Guards against inline port detection re-emerging in review.sh, verify-acs.sh, or other scripts. Per T-1105 chokepoint+invariant-test discipline.

## Acceptance Criteria

### Agent
- [x] `tests/lint/single-port-detection.bats` exists with 5+ tests
- [x] All bats tests pass

## Verification

bash -c 'test -f tests/lint/single-port-detection.bats'
bash -c 'cd /opt/999-Agentic-Engineering-Framework && bats tests/lint/single-port-detection.bats'

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

### 2026-04-12T11:45:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1155-t-1154-invariant-test--single-port-detec.md
- **Context:** Initial task creation

### 2026-04-12T11:46:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
