---
id: T-1024
name: "Add /api/patterns endpoint — JSON API for failure/success/workflow patterns"
description: >
  Complete context fabric API trio: concerns (T-1022), learnings+decisions (T-1023), patterns

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_patterns.py, C-003]
related_tasks: []
created: 2026-04-07T11:43:59Z
last_update: 2026-04-07T11:45:11Z
date_finished: 2026-04-07T11:45:11Z
---

# T-1024: Add /api/patterns endpoint — JSON API for failure/success/workflow patterns

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `/api/patterns` endpoint returns JSON with grouped patterns and counts
- [x] Playwright tests cover the endpoint (2 tests)
- [x] All tests pass

### Human
<!-- No human ACs needed
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

### 2026-04-07T11:43:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1024-add-apipatterns-endpoint--json-api-for-f.md
- **Context:** Initial task creation

### 2026-04-07T11:45:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
