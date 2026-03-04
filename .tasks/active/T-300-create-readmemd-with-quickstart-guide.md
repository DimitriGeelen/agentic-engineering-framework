---
id: T-300
name: "Create README.md with quickstart guide"
description: >
  Framework repo has no README.md — zero entry point for humans. FRAMEWORK.md is agent-facing, not human-facing. Need: one-paragraph description, prerequisites (python3, git, bash), install (3 commands), bootstrap project (fw init, fw doctor), first task (fw work-on), links to FRAMEWORK.md and CLAUDE.md. Target: ~50-100 lines. Source: T-294 simulation O-001, new-user-perspective agent.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:16:05Z
last_update: 2026-03-04T16:16:05Z
date_finished: null
---

# T-300: Create README.md with quickstart guide

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

### 2026-03-04T16:16:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-300-create-readmemd-with-quickstart-guide.md
- **Context:** Initial task creation
