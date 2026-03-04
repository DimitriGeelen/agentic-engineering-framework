---
id: T-304
name: "Build opt-out first-run experience after fw init"
description: >
  After fw init completes, automatically run a guided first-governance-cycle walkthrough (5 steps: create task, make change, commit with traceability, run audit, generate handover). Opt-out via --no-first-run flag on fw init. Shows the user the framework doing something useful immediately — closes the 'cargo run gap' from DX comparison. Prints each step, executes it, validates result. Source: T-294 DX comparison, Area 6B.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-04T16:27:33Z
last_update: 2026-03-04T16:27:33Z
date_finished: null
---

# T-304: Build opt-out first-run experience after fw init

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

### 2026-03-04T16:27:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-304-build-opt-out-first-run-experience-after.md
- **Context:** Initial task creation
