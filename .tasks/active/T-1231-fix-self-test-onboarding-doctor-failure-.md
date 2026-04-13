---
id: T-1231
name: "Fix self-test onboarding doctor failure — diagnose and resolve pre-existing issue"
description: >
  Fix self-test onboarding doctor failure — diagnose and resolve pre-existing issue

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T13:53:13Z
last_update: 2026-04-13T13:53:13Z
date_finished: null
---

# T-1231: Fix self-test onboarding doctor failure — diagnose and resolve pre-existing issue

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Root cause investigation: "Hook path validation: 17/17 hooks have broken paths" in self-test
- [x] Manual reproduction passes (doctor returns 0 with all 17 hooks portable)
- [ ] Identify why self-test context differs from manual (may be concurrent test interference)
- [ ] `fw self-test onboarding` passes (0 failures)

## Verification

bin/fw self-test onboarding 2>&1 | grep -q '0.*failed\|5/5 phases'

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
