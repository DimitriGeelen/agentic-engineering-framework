---
id: T-1097
name: "fw doctor: reconcile upstream_repo vs running fw resolution path — flag ambiguity (G-028)"
description: >
  When .framework.yaml carries upstream_repo: <path> and the running fw resolves through a different path (host install, brew Cellar, vendored .agentic-framework/), fw doctor should print BOTH paths and flag if they diverge. Currently agents have no way to know which is canonical. Origin: G-028. Trigger: cross-session ring20-dashboard onboarding incident 2026-04-11 — three potential framework paths in play (.framework.yaml upstream_repo + ~/.local/bin/fw symlink target + actual running install) with no surface to reconcile them.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1093]
created: 2026-04-11T12:15:51Z
last_update: 2026-04-11T12:15:51Z
date_finished: null
---

# T-1097: fw doctor: reconcile upstream_repo vs running fw resolution path — flag ambiguity (G-028)

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

### 2026-04-11T12:15:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1097-fw-doctor-reconcile-upstreamrepo-vs-runn.md
- **Context:** Initial task creation
