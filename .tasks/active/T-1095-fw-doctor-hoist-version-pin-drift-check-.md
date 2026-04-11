---
id: T-1095
name: "fw doctor: hoist version-pin drift check from lib/upgrade.sh as a read-only doctor check (G-026)"
description: >
  Add a fw doctor check that runs the same version-pin detection as fw upgrade (e.g. 'Pinned: vdev (behind v2.46.alpha)') without applying changes. Surfaces stale pins between upgrade runs. Origin: G-026. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1093]
created: 2026-04-11T12:15:36Z
last_update: 2026-04-11T12:15:36Z
date_finished: null
---

# T-1095: fw doctor: hoist version-pin drift check from lib/upgrade.sh as a read-only doctor check (G-026)

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

### 2026-04-11T12:15:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1095-fw-doctor-hoist-version-pin-drift-check-.md
- **Context:** Initial task creation
