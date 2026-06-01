---
id: T-1231
name: "Fix self-test onboarding doctor failure — diagnose and resolve pre-existing issue"
description: >
  Fix self-test onboarding doctor failure — diagnose and resolve pre-existing issue

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T13:53:13Z
last_update: 2026-04-13T14:03:39Z
date_finished: 2026-04-13T14:03:39Z
---

# T-1231: Fix self-test onboarding doctor failure — diagnose and resolve pre-existing issue

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Root cause: inherited PROJECT_ROOT env var from framework session causes doctor to validate wrong project
- [x] Fix: unset PROJECT_ROOT before running doctor in self-test subshell
- [x] `fw self-test onboarding` passes (5/5 phases, 0 failures)

## Verification

# Verify the fix is in the test file
grep -q 'unset PROJECT_ROOT' tests/e2e/onboarding-test.sh

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

### 2026-04-13T13:53:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1231-fix-self-test-onboarding-doctor-failure-.md
- **Context:** Initial task creation

### 2026-04-13T14:03:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Root cause: inherited PROJECT_ROOT. Fix: unset in self-test subshell. 5/5 phases pass.
