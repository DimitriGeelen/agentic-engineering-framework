---
id: T-315
name: "Build fw upgrade command (audit, propose, apply)"
description: >
  Rails-style interactive upgrade for frozen artifacts. Phase 1: audit (hash frozen files vs current framework). Phase 2: propose (diff report per file). Phase 3: apply (replace/keep/merge per file, backup originals). Covers: settings.json hooks, CLAUDE.md sections, task templates, seed YAML merge by ID, git hooks reinstall, version marker update. Source: T-306 investigation, Agents 2+6+8+9 findings.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-04T19:27:23Z
last_update: 2026-03-04T19:27:23Z
date_finished: null
---

# T-315: Build fw upgrade command (audit, propose, apply)

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

### 2026-03-04T19:27:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-315-build-fw-upgrade-command-audit-propose-a.md
- **Context:** Initial task creation
