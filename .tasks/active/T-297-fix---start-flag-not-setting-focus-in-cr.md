---
id: T-297
name: "Fix --start flag not setting focus in create-task.sh"
description: >
  create-task.sh --start sets status to started-work but does not call context.sh focus. Tier 1 hook blocks Write/Edit because focus.yaml has current_task: null. Fix: add context.sh focus call when START_WORK=true, matching the pattern in fw work-on (bin/fw:1139). Source: T-294 simulation O-008.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:11:41Z
last_update: 2026-03-04T16:11:41Z
date_finished: null
---

# T-297: Fix --start flag not setting focus in create-task.sh

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
<!-- Remove this section if all criteria are agent-verifiable. -->

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

### 2026-03-04T16:11:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-297-fix---start-flag-not-setting-focus-in-cr.md
- **Context:** Initial task creation
