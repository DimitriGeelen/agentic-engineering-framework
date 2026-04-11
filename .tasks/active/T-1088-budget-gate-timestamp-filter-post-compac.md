---
id: T-1088
name: "Budget gate timestamp-filter post-compact JSONL read (real T-1087 fix)"
description: >
  Option 1 from T-1087 RCA: budget-gate.sh and checkpoint.sh both read last usage entry across the whole JSONL, which after /compact can include pre-compact entries because claude -c continues the same JSONL. Real fix: filter JSONL entries by timestamp during the Python scan, taking only entries with timestamp > SESSION_START_TS. post-compact-resume.sh should write .session-start-ts; budget-gate and checkpoint should read it. Includes JSONL schema verification and unit tests for the post-compact window.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-04-11T10:31:55Z
last_update: 2026-04-11T10:31:55Z
date_finished: null
---

# T-1088: Budget gate timestamp-filter post-compact JSONL read (real T-1087 fix)

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

### 2026-04-11T10:31:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1088-budget-gate-timestamp-filter-post-compac.md
- **Context:** Initial task creation
