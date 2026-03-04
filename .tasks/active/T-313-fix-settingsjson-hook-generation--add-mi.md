---
id: T-313
name: "Fix settings.json hook generation — add missing 5 hooks"
description: >
  Consumer projects get 5 of 10 hooks at init time. Missing: budget-gate, block-plan-mode, pre-compact, check-dispatch, resume SessionStart matcher. Update generate_claude_code_config() in lib/init.sh to emit all hooks. Source: T-306 investigation, Agent 4 findings.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-04T19:27:05Z
last_update: 2026-03-04T19:27:05Z
date_finished: null
---

# T-313: Fix settings.json hook generation — add missing 5 hooks

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

### 2026-03-04T19:27:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-313-fix-settingsjson-hook-generation--add-mi.md
- **Context:** Initial task creation
