---
id: T-1159
name: "T-1136 build: Show open concerns at session init — cross-session failure awareness"
description: >
  T-1136 build: Show open concerns at session init — cross-session failure awareness

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/lib/init.sh]
related_tasks: []
created: 2026-04-12T12:06:20Z
last_update: 2026-04-12T12:08:11Z
date_finished: 2026-04-12T12:08:11Z
---

# T-1159: T-1136 build: Show open concerns at session init — cross-session failure awareness

## Context

Build from T-1136 GO. Open concerns are invisible at session start — agents must explicitly run `fw gaps`. Adding concerns summary to init output prevents cross-session failure blindness.

## Acceptance Criteria

### Agent
- [x] `agents/context/lib/init.sh` shows open concerns count at session init
- [x] Silent when no open concerns (backward compatible)
- [x] `fw context init` output includes "Concerns register" when concerns exist

## Verification

bash -c 'grep -q "concerns" agents/context/lib/init.sh'
bash -c 'bin/fw context init 2>&1 | grep -qi "concern"'

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

### 2026-04-12T12:06:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1159-t-1136-build-show-open-concerns-at-sessi.md
- **Context:** Initial task creation

### 2026-04-12T12:08:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
