---
id: T-1096
name: "Boundary hook: surface TermLink dispatch read-only escape route in BLOCK message (G-027)"
description: >
  Extend agents/context/check-project-boundary.sh BLOCK message (the same one updated in T-1089 for write ops) to mention 'fw termlink dispatch --project /path --prompt cat README.md' as the read-only escape pattern. Currently agents must ask the human to authorize each cross-project read individually. Origin: G-027. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11 — agent needed to read sibling READMEs and had no documented escape.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1093, T-1089]
created: 2026-04-11T12:15:46Z
last_update: 2026-04-11T12:15:46Z
date_finished: null
---

# T-1096: Boundary hook: surface TermLink dispatch read-only escape route in BLOCK message (G-027)

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

### 2026-04-11T12:15:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1096-boundary-hook-surface-termlink-dispatch-.md
- **Context:** Initial task creation
