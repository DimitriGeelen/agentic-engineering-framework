---
id: T-1022
name: "Add /api/concerns endpoint — JSON API for gaps register"
description: >
  Add JSON API endpoint for the concerns/gaps register to make the data accessible to the cockpit and other API consumers

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_quality.py, web/blueprints/quality.py]
related_tasks: []
created: 2026-04-07T11:40:41Z
last_update: 2026-04-07T11:42:06Z
date_finished: 2026-04-07T11:42:06Z
---

# T-1022: Add /api/concerns endpoint — JSON API for gaps register

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `/api/concerns` endpoint returns JSON with concerns data
- [x] Response includes counts by severity and status
- [x] Playwright test covers the endpoint (3 tests)
- [x] Endpoint accessible and returns valid JSON

### Human
<!-- No human ACs needed — API endpoint with deterministic output
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

### 2026-04-07T11:40:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1022-add-apiconcerns-endpoint--json-api-for-g.md
- **Context:** Initial task creation

### 2026-04-07T11:42:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3aa7712a
- **Timestamp:** 2026-06-02T14:54:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
