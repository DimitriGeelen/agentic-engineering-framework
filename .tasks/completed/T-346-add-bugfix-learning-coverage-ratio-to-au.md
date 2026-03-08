---
id: T-346
name: "Add bugfix-learning coverage ratio to audit section 5"
description: >
  Detective control for G-016: audit checks ratio of bugfix tasks with learnings. Warn below 40%.

status: work-completed
workflow_type: build
owner: agent
horizon: next
tags: [meta, audit, learning]
components: [C-004, bin/fw]
related_tasks: []
created: 2026-03-08T12:34:04Z
last_update: 2026-03-08T14:09:55Z
date_finished: 2026-03-08T14:09:55Z
---

# T-346: Add bugfix-learning coverage ratio to audit section 5

## Context

Detective control for G-016: audit section 5 now checks ratio of completed bugfix tasks that have associated learnings in learnings.yaml. Warns below 40%.

## Acceptance Criteria

### Agent
- [x] Audit section 5 (learning) includes bugfix-learning coverage check
- [x] Check counts completed tasks with "fix" or "bug" in name, cross-refs learnings.yaml
- [x] Warns below 40% coverage with actionable mitigation message

## Verification

grep -q "Bugfix-learning coverage" <(fw audit --section learning 2>&1)

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

### 2026-03-08T12:34:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-346-add-bugfix-learning-coverage-ratio-to-au.md
- **Context:** Initial task creation

### 2026-03-08T14:04:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T14:09:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
