---
id: T-286
name: "Build fw self-audit CLI command and standalone script"
description: >
  Build agents/audit/self-audit.sh as a standalone script that runs mechanical checks (Layers 1-4, syntax, directories) without needing Claude Code. Wire it into bin/fw as 'fw self-audit'. The script reads docs/prompts/framework-self-audit.md for the check specifications but executes them mechanically. Produces a structured report. Does NOT depend on fw itself (solves the chicken-and-egg problem). Follow-up to T-285 which created the prompt file.

status: captured
workflow_type: build
owner: human
horizon: next
tags: [audit, deployment, cli]
components: []
related_tasks: []
created: 2026-03-01T09:37:55Z
last_update: 2026-03-01T09:37:55Z
date_finished: null
---

# T-286: Build fw self-audit CLI command and standalone script

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

### 2026-03-01T09:37:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-286-build-fw-self-audit-cli-command-and-stan.md
- **Context:** Initial task creation
