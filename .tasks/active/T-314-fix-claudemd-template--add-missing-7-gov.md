---
id: T-314
name: "Fix CLAUDE.md template — add missing 7 governance sections"
description: >
  Consumer CLAUDE.md template (lib/templates/claude-project.md or inline in init.sh) missing 7 of 18 major sections: authority model, error escalation, budget mgmt, sub-agent dispatch protocol, plan prohibition, behavioral rules, component fabric. ~70%% governance loss. Update template to include all governance sections. Source: T-306 investigation, Agent 5 findings.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-04T19:27:14Z
last_update: 2026-03-04T19:27:14Z
date_finished: null
---

# T-314: Fix CLAUDE.md template — add missing 7 governance sections

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

### 2026-03-04T19:27:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-314-fix-claudemd-template--add-missing-7-gov.md
- **Context:** Initial task creation
