---
id: T-1023
name: "Add /api/learnings and /api/decisions endpoints — JSON APIs for context fabric"
description: >
  Expose learnings and decisions data as JSON APIs for programmatic access

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_discovery.py, C-003]
related_tasks: []
created: 2026-04-07T11:42:19Z
last_update: 2026-04-07T11:43:42Z
date_finished: 2026-04-07T11:43:42Z
---

# T-1023: Add /api/learnings and /api/decisions endpoints — JSON APIs for context fabric

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `/api/learnings` endpoint returns JSON with learnings data and counts
- [x] `/api/decisions` endpoint returns JSON with decisions data and counts
- [x] Playwright tests cover both endpoints (4 tests)
- [x] All tests pass

### Human
<!-- No human ACs needed — API endpoints with deterministic output
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

### 2026-04-07T11:42:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1023-add-apilearnings-and-apidecisions-endpoi.md
- **Context:** Initial task creation

### 2026-04-07T11:43:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b0b58881
- **Timestamp:** 2026-06-02T14:54:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
