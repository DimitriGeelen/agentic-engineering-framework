---
id: T-576
name: "PICKUP-006: CLAUDECODE env var blocks TermLink agent spawning"
description: >
  From 150-skills-manager via TermLink. HIGH. CLAUDECODE env var inherited by TermLink-spawned sessions blocks nested Claude Code. Requires env -u CLAUDECODE workaround. Framework TermLink integration should handle this automatically (claude-fw wrapper or termlink spawn). Already hit during T-549 eval session. Pickup: /opt/150-skills-manager/.context/handovers/pickup-006-termlink-claudecode-nesting.md. Learning: L-015.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/termlink/termlink.sh]
related_tasks: []
created: 2026-03-23T20:58:40Z
last_update: 2026-03-24T11:53:36Z
date_finished: 2026-03-24T11:53:36Z
---

# T-576: PICKUP-006: CLAUDECODE env var blocks TermLink agent spawning

## Context

Fix already applied in T-586 session: `unset CLAUDECODE` in `agents/termlink/termlink.sh:243`. Learning L-015 and pattern captured. Task just needs formal closure.

## Acceptance Criteria

### Agent
- [x] `unset CLAUDECODE` present in termlink.sh worker script (line 243)
- [x] Learning captured in learnings.yaml
- [x] Pattern captured in patterns.yaml

## Verification

grep -q "unset CLAUDECODE" agents/termlink/termlink.sh

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

### 2026-03-23T20:58:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-576-pickup-006-claudecode-env-var-blocks-ter.md
- **Context:** Initial task creation

### 2026-03-24T11:53:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T11:53:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
