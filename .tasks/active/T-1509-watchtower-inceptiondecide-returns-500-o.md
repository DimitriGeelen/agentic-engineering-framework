---
id: T-1509
name: "Watchtower /inception/decide returns 500 on partial-complete success — record_decision misreads stdout (split from T-1503)"
description: >
  Split from T-1503 P-010. update-task.sh exits non-zero in post-transition path under set -euo pipefail (auto-decisions, components resolver, learning detector, or similar). web/blueprints/inception.py:411 record_decision treats non-zero exit as failure → 500 to user. Underlying transition succeeded. Fix area: defensive parse of stdout success markers in record_decision + RCA the spurious non-zero exit in update-task.sh post-transition path.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-04-26T12:05:09Z
last_update: 2026-04-26T12:05:21Z
date_finished: null
---

# T-1509: Watchtower /inception/decide returns 500 on partial-complete success — record_decision misreads stdout (split from T-1503)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-26T12:05:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1509-watchtower-inceptiondecide-returns-500-o.md
- **Context:** Initial task creation

### 2026-04-26T12:05:21Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
