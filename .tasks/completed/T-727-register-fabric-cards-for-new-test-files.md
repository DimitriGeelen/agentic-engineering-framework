---
id: T-727
name: "Register fabric cards for new test files + session housekeeping"
description: >
  Register fabric cards for new test files + session housekeeping

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T20:03:11Z
last_update: 2026-03-29T20:06:30Z
date_finished: 2026-03-29T20:06:30Z
---

# T-727: Register fabric cards for new test files + session housekeeping

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Fabric cards created for tests/integration/fw_version.bats and tests/integration/fw_cron.bats
- [x] `fw fabric drift` reports 0 unregistered, 0 orphaned, 0 stale

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

### 2026-03-29T20:03:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-727-register-fabric-cards-for-new-test-files.md
- **Context:** Initial task creation

### 2026-03-29T20:06:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1049e381
- **Timestamp:** 2026-06-02T15:04:35Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Fabric cards created for tests/integration/fw_version.bats and tests/integration/fw_cron.bats
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/integration/fw_version.bats in: Fabric cards created for tests/integration/fw_version.bats and tests/integration/fw_cron.bats`
