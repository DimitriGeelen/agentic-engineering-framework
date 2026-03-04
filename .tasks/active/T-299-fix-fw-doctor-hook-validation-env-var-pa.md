---
id: T-299
name: "Fix fw doctor hook validation env var parsing"
description: >
  fw doctor FAILS on every new project with 'script not found'. Root cause: bin/fw:392 uses command.split()[0] to extract script path from hook commands, but grabs PROJECT_ROOT=... env var assignment instead of the actual script path. Fix: skip tokens containing '=' when extracting script path. Source: T-294 simulation O-003.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:14:53Z
last_update: 2026-03-04T16:14:53Z
date_finished: null
---

# T-299: Fix fw doctor hook validation env var parsing

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

### 2026-03-04T16:14:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-299-fix-fw-doctor-hook-validation-env-var-pa.md
- **Context:** Initial task creation
