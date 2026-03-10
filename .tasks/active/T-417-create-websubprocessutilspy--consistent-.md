---
id: T-417
name: "Create web/subprocess_utils.py — consistent git/fw command execution (P7)"
description: >
  Create web/subprocess_utils.py with run_git_command() and run_fw_command() helpers. Currently 3 separate subprocess implementations with inconsistent timeouts (none vs 10s), error checking, and encoding. Directive score: P7=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: captured
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, python, watchtower, reliability]
components: []
related_tasks: []
created: 2026-03-10T21:03:17Z
last_update: 2026-03-10T21:03:17Z
date_finished: null
---

# T-417: Create web/subprocess_utils.py — consistent git/fw command execution (P7)

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

### 2026-03-10T21:03:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-417-create-websubprocessutilspy--consistent-.md
- **Context:** Initial task creation
