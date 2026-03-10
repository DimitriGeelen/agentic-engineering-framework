---
id: T-203
name: "Scratch test — partial-complete verification"
description: >
  Temporary task to verify P-010 AC split and partial-complete behavior. Delete after testing.

status: work-completed
workflow_type: test
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T21:43:44Z
last_update: 2026-02-19T21:45:08Z
date_finished: 2026-02-19T21:44:11Z
---

# T-203: Scratch test — partial-complete verification

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Task file exists with both AC sections
- [x] Verification section is present

### Human
- [x] Visual confirmation that partial-complete works
- [x] Cockpit renders this task in verification section

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

### 2026-02-19T21:43:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-203-scratch-test--partial-complete-verificat.md
- **Context:** Initial task creation

### 2026-02-19T21:44:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T21:44:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
