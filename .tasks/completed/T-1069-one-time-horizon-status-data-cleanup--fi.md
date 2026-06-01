---
id: T-1069
name: "One-time horizon-status data cleanup — fix 52 inconsistent tasks"
description: >
  Move 24 stuck work-completed tasks to completed/. Fix 28 started-work tasks with wrong horizon (demote to captured). Origin: T-1067 GO.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-08T10:32:46Z
last_update: 2026-04-08T10:39:19Z
date_finished: 2026-04-08T10:39:19Z
---

# T-1069: One-time horizon-status data cleanup — fix 52 inconsistent tasks

## Context

Origin: T-1067 GO. Fix existing data to match new invariants from T-1068.

## Acceptance Criteria

### Agent
- [x] 28 started-work + horizon:next/later tasks demoted to captured
- [x] 24 stuck work-completed tasks (all ACs checked) moved to completed/
- [x] No started-work tasks with horizon != now remain (0 violations)
- [x] No work-completed tasks with all ACs checked remain in active/ (77 remaining are legitimate partial-completes)

## Verification

# No started-work tasks with wrong horizon
test $(for f in .tasks/active/T-*.md; do s=$(grep '^status:' "$f" | head -1 | sed 's/status: *//'); h=$(grep '^horizon:' "$f" | head -1 | sed 's/horizon: *//'); [ "$s" = "started-work" ] && [ "$h" != "now" ] && echo bad; done | wc -l) -eq 0

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

### 2026-04-08T10:32:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1069-one-time-horizon-status-data-cleanup--fi.md
- **Context:** Initial task creation

### 2026-04-08T10:38:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-08T10:39:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
