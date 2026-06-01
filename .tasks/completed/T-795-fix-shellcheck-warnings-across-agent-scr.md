---
id: T-795
name: "Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044"
description: >
  Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: [C-007, agents/handover/handover.sh, agents/task-create/create-task.sh, agents/task-create/update-task.sh, agents/termlink/termlink.sh]
related_tasks: []
created: 2026-03-30T16:28:06Z
last_update: 2026-03-30T16:31:31Z
date_finished: 2026-03-30T16:31:31Z
---

# T-795: Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044

## Context

Batch fix for shellcheck warnings across 5 agent scripts: handover.sh, update-task.sh, create-task.sh, budget-gate.sh, termlink.sh. Skipping audit.sh (complex, separate task) and mcp-reaper.sh/onboarding-test (lower priority).

## Acceptance Criteria

### Agent
- [x] shellcheck warnings fixed in handover.sh (SC2034 unused LAST_COMMIT removed, SC2044 find-in-for-loop), update-task.sh (SC2144 glob with -f), create-task.sh (SC2034 unused TEMPLATE, SC2155), budget-gate.sh (SC2034 suppressed with comment, SC2038 xargs -0), termlink.sh (SC1083 @{u} quoting)
- [x] All 5 modified scripts pass `bash -n` syntax check
- [x] All 5 modified scripts pass `shellcheck -S warning` with 0 findings

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n agents/handover/handover.sh
bash -n agents/task-create/update-task.sh
bash -n agents/task-create/create-task.sh
bash -n agents/context/budget-gate.sh
bash -n agents/termlink/termlink.sh
shellcheck -S warning agents/handover/handover.sh agents/task-create/update-task.sh agents/task-create/create-task.sh agents/context/budget-gate.sh agents/termlink/termlink.sh

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

### 2026-03-30T16:28:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-795-fix-shellcheck-warnings-across-agent-scr.md
- **Context:** Initial task creation

### 2026-03-30T16:31:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
