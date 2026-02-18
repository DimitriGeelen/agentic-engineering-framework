---
id: T-163
name: "Regression suite runner — single command to validate framework health"
description: >
  Create fw test command that runs: ShellCheck on all .sh files, bats unit tests, bats integration tests, pytest web tests, test-tier0-patterns.py. Report: pass/fail/skip counts, coverage summary. Integrate with fw doctor (add test check). Consider pre-push hook integration. Ref: T-158

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:30:57Z
last_update: 2026-02-18T13:30:57Z
date_finished: null
---

# T-163: Regression suite runner — single command to validate framework health

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-02-18T13:30:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-163-regression-suite-runner--single-command-.md
- **Context:** Initial task creation
