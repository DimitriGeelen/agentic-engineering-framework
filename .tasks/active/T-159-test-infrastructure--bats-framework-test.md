---
id: T-159
name: "Test infrastructure — bats framework, test runner, fw test command"
description: >
  Install bats (Bash Automated Testing System). Create tests/ directory structure (unit/, integration/, fixtures/, mocks/). Add fw test command that runs all tests (bats + pytest). Add ShellCheck linting. Ref: T-158 inception, /tmp/T-158-bash-audit.md

status: started-work
workflow_type: build
owner: agent
horizon: later
tags: []
related_tasks: []
created: 2026-02-18T13:30:27Z
last_update: 2026-02-18T13:59:20Z
date_finished: null
---

# T-159: Test infrastructure — bats framework, test runner, fw test command

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

### 2026-02-18T13:30:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-159-test-infrastructure--bats-framework-test.md
- **Context:** Initial task creation

### 2026-02-18T13:59:20Z — status-update [task-update-agent]
- **Change:** horizon: now → later
