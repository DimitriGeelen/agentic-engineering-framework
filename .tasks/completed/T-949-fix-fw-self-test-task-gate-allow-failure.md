---
id: T-949
name: "Fix fw self-test task-gate-allow failure — gate test expects exit 0, gets 2"
description: >
  Fix fw self-test task-gate-allow failure — gate test expects exit 0, gets 2

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T10:49:01Z
last_update: 2026-04-06T10:51:34Z
date_finished: 2026-04-06T10:51:34Z
---

# T-949: Fix fw self-test task-gate-allow failure — gate test expects exit 0, gets 2

## Context

fw self-test gates test "task-gate-allow" fails because fw init creates onboarding tasks, and the onboarding gate blocks non-onboarding writes. Fix: add .onboarding-complete marker in test setup.

## Acceptance Criteria

### Agent
- [x] gates-test.sh marks onboarding complete in test dir
- [x] fw self-test gates all pass (5/5)

## Verification

bash tests/e2e/gates-test.sh 2>&1 | grep -q 'All 5 gate tests passed'

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

### 2026-04-06T10:49:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-949-fix-fw-self-test-task-gate-allow-failure.md
- **Context:** Initial task creation

### 2026-04-06T10:51:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
