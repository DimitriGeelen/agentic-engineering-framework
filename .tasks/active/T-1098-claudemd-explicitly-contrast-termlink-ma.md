---
id: T-1098
name: "CLAUDE.md: explicitly contrast termlink (machine-wide) vs framework (per-project) distribution models (G-029)"
description: >
  Add a section or sentence to CLAUDE.md §TermLink Integration that states termlink is intentionally machine-wide because session discovery uses Unix sockets at system paths — per-project isolation would defeat cross-session discovery. Frame as the deliberate inverse of framework code (per-project governance). Stops agents from proposing per-project termlink vendoring. Origin: G-029. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1093]
created: 2026-04-11T12:15:59Z
last_update: 2026-04-11T12:15:59Z
date_finished: null
---

# T-1098: CLAUDE.md: explicitly contrast termlink (machine-wide) vs framework (per-project) distribution models (G-029)

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

### 2026-04-11T12:15:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1098-claudemd-explicitly-contrast-termlink-ma.md
- **Context:** Initial task creation
