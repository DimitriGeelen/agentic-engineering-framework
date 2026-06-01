---
id: T-1236
name: "Fix malformed episodic YAML — T-269 and T-675 parse errors on every /search load"
description: >
  Fix malformed episodic YAML — T-269 and T-675 parse errors on every /search load

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T18:52:00Z
last_update: 2026-04-13T18:55:09Z
date_finished: 2026-04-13T18:55:09Z
---

# T-1236: Fix malformed episodic YAML — T-269 and T-675 parse errors on every /search load

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] T-269 episodic parses without error — fixed decision structure
- [x] T-675 episodic parses without error — stripped backslash escapes, regenerated
- [x] No YAML parse errors in server log on /search load — 0 broken files remain

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

### 2026-04-13T18:52:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1236-fix-malformed-episodic-yaml--t-269-and-t.md
- **Context:** Initial task creation

### 2026-04-13T18:55:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Both episodics fixed, 0 broken files across 1166 episodics
