---
id: T-453
name: "PR #4: T-002: Fix governance activation gap in fw init"
description: >
  OneDev PR #4 (branch: fix/T-002-governance-activation-gap)

Calls fw context init at end of do_init() so governance is active immediately after fw init. Hardens check-active-task.sh to block when .framework.yaml exists but focus.yaml missing. Adds integration test.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [onedev, pr]
components: []
related_tasks: []
created: 2026-03-12T10:15:03Z
last_update: 2026-03-12T10:15:03Z
date_finished: 2026-03-12T13:00:47Z
---

# T-453: PR #4: T-002: Fix governance activation gap in fw init

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] [First criterion]
- [x] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
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

### 2026-03-12T10:15:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-453-pr-4-t-002-fix-governance-activation-gap.md
- **Context:** Initial task creation
