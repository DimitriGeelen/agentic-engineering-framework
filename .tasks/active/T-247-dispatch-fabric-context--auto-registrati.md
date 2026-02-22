---
id: T-247
name: "Dispatch fabric context + auto-registration — close agent blind spots"
description: >
  Two related fixes for agent blind spots: (1) Update dispatch preamble (agents/dispatch/preamble.md) to include fabric awareness guidance — sub-agents should run fw fabric deps before modifying registered components. Currently dispatch preamble has zero fabric references and cross-agent awareness scores 1/10. (2) Add auto-registration of new files in post-commit hook — when git diff shows files not matching any component card, run fw fabric scan on them (advisory, not blocking). Currently new files created during tasks don't get registered until manual fw fabric register. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 1 Gaps 3-5. Also: /tmp/fw-agent-fabric-status.md §3.4 and §3.5. Related: T-236 (blast-radius in post-commit — done, extend same hook), T-244 (pre-edit awareness — companion task).

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [fabric, dispatch, auto-registration]
components: []
related_tasks: []
created: 2026-02-22T09:29:59Z
last_update: 2026-02-22T09:29:59Z
date_finished: null
---

# T-247: Dispatch fabric context + auto-registration — close agent blind spots

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

### 2026-02-22T09:29:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-247-dispatch-fabric-context--auto-registrati.md
- **Context:** Initial task creation
