---
id: T-161
name: "Hook and gate integration tests — 5 critical enforcement scripts"
description: >
  Write integration tests for: budget-gate.sh, check-active-task.sh, check-tier0.sh (extend existing), checkpoint.sh, error-watchdog.sh. Requires mock JSONL transcripts, mock git repos, mock focus.yaml. These are critical path — 0% coverage currently. Ref: T-158, /tmp/T-158-hooks-and-bugs.md

status: captured
workflow_type: test
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:30:45Z
last_update: 2026-02-18T13:30:45Z
date_finished: null
---

# T-161: Hook and gate integration tests — 5 critical enforcement scripts

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

### 2026-02-18T13:30:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-161-hook-and-gate-integration-tests--5-criti.md
- **Context:** Initial task creation
