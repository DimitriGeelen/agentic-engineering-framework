---
id: T-1495
name: "Pickup: Watchtower discovery (_watchtower_url) fails closed when /api/_identity returns 404; fw serve writes triple-file non-atomically (partial state observed); fw doctor misdiagnoses partial triple as stale pid (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-141. Type: bug-report.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-26T11:12:02Z
last_update: 2026-04-26T11:12:02Z
date_finished: null
source_task_id_in_origin: T-141
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1495: Pickup: Watchtower discovery (_watchtower_url) fails closed when /api/_identity returns 404; fw serve writes triple-file non-atomically (partial state observed); fw doctor misdiagnoses partial triple as stale pid (from 003-NTB-ATC-Plugin)

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

### 2026-04-26T11:12:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1495-pickup-watchtower-discovery-watchtowerur.md
- **Context:** Initial task creation
