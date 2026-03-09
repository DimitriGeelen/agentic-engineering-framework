---
id: T-367
name: "Auto-generate watch-patterns.yaml on fw context init"
description: >
  When .fabric/watch-patterns.yaml doesn't exist, fw context init should generate a default from common source patterns (src/**/*.py, **/*.ts, **/*.go, etc). Unblocks fw fabric scan for non-framework projects. See R-1 in fabric silent-degradation analysis.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [fabric, onboarding]
components: [agents/context/lib/init.sh]
related_tasks: []
created: 2026-03-08T22:27:27Z
last_update: 2026-03-08T22:57:05Z
date_finished: 2026-03-08T22:57:05Z
---

# T-367: Auto-generate watch-patterns.yaml on fw context init

## Context

R-1 from fabric silent-degradation analysis. fw fabric scan fails on new projects because watch-patterns.yaml doesn't exist and there's no default.

## Acceptance Criteria

### Agent
- [x] fw context init generates watch-patterns.yaml when missing and .fabric/ exists
- [x] Default patterns cover common source layouts (py, rs, sh, ts, go)
- [x] Skips generation if file already exists
- [x] Prints confirmation message when generated

## Verification

grep -q "watch-patterns" agents/context/lib/init.sh
grep -q "src/\*\*/\*.py" agents/context/lib/init.sh

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

### 2026-03-08T22:27:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-367-auto-generate-watch-patternsyaml-on-fw-c.md
- **Context:** Initial task creation

### 2026-03-08T22:32:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T22:57:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
