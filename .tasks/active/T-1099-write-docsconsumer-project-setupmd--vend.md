---
id: T-1099
name: "Write docs/consumer-project-setup.md — vendoring + shim + termlink onboarding walkthrough (G-030)"
description: >
  Create docs/consumer-project-setup.md with: how to clone target project, how to fw init, when/why to fw upgrade, what .framework.yaml fields mean (especially upstream_repo), shim vs vendored isolation models (link to G-031), termlink install (system-wide via brew, NOT per-project), and a worked example. Link from README.md and CLAUDE.md. Origin: G-030. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1093, T-1094, T-1098]
created: 2026-04-11T12:16:03Z
last_update: 2026-04-11T12:16:03Z
date_finished: null
---

# T-1099: Write docs/consumer-project-setup.md — vendoring + shim + termlink onboarding walkthrough (G-030)

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

### 2026-04-11T12:16:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1099-write-docsconsumer-project-setupmd--vend.md
- **Context:** Initial task creation
