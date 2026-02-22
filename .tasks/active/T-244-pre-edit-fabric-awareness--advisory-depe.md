---
id: T-244
name: "Pre-edit fabric awareness — advisory dependency check on Write/Edit"
description: >
  Add lightweight PreToolUse advisory check: when agent edits a source file, look up the file in .fabric/components/ and inject dependency count + key dependents into context. Not blocking — just awareness. T-235 Gap #1: 'Fabric invisible to working agents — no agent checks deps before modifying files.' CLAUDE.md says 'Before modifying a file: fw fabric deps <path>' but this is guidance only. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 1 Gap 1. Related: T-236 (blast-radius in post-commit — done), T-224 (component auto-populate on completion — done). This closes the pre-edit gap. Example: agent edits bin/fw (15 dependents) and sees 'NOTE: bin/fw has 15 downstream dependents — consider fw fabric blast-radius after commit.'

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [fabric, enforcement, awareness]
components: []
related_tasks: []
created: 2026-02-22T09:29:28Z
last_update: 2026-02-22T09:29:28Z
date_finished: null
---

# T-244: Pre-edit fabric awareness — advisory dependency check on Write/Edit

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

### 2026-02-22T09:29:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-244-pre-edit-fabric-awareness--advisory-depe.md
- **Context:** Initial task creation
