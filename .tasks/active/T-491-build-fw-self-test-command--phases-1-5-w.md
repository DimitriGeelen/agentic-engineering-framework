---
id: T-491
name: "Build fw self-test command — phases 1-5 with JSON output and CI integration"
description: >
  From T-490 GO. Build agents/self-test/self-test.sh with 5 phases: (1) preflight — deps, temp project; (2) gate validation — Tier 0/1/2 via exit codes; (3) task lifecycle — create/update/complete; (4) Watchtower — start on :9877, poll health, run smoke_test.py; (5) cleanup + JSON report. Also fix fw doctor exit code bug (always returns 0). Key constraints: all lifecycle in single chained commands (shell state doesn't persist), sleep 4 for Flask startup, pipe JSON to stdin for hook scripts.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [testing, self-test, ci]
components: []
related_tasks: []
created: 2026-03-14T17:05:01Z
last_update: 2026-03-14T17:05:01Z
date_finished: null
---

# T-491: Build fw self-test command — phases 1-5 with JSON output and CI integration

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

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-14T17:05:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-491-build-fw-self-test-command--phases-1-5-w.md
- **Context:** Initial task creation
