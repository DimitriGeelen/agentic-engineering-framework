---
id: T-921
name: "Add unit tests for agents/task-create/create-task.sh"
description: >
  Add unit tests for agents/task-create/create-task.sh

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [tests/unit/create_task.bats]
related_tasks: []
created: 2026-04-05T16:02:31Z
last_update: 2026-04-05T16:04:28Z
date_finished: 2026-04-05T16:04:28Z
---

# T-921: Add unit tests for agents/task-create/create-task.sh

## Context

agents/task-create/ has no unit tests. Testing create-task.sh core functions: slug generation, ID generation, YAML array formatting, placeholder rejection, help text, and full task creation.

## Acceptance Criteria

### Agent
- [x] Test file exists at tests/unit/create_task.bats
- [x] Tests cover generate_slug (3 tests: lowercase, hyphens, truncation)
- [x] Tests cover format_yaml_array (via tags test)
- [x] Tests cover placeholder name rejection (3 tests)
- [x] Tests cover help flag
- [x] Tests cover full task creation (5 tests: basic, tags, horizon, start, inception)
- [x] All tests pass (17/17)

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

### 2026-04-05T16:02:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-921-add-unit-tests-for-agentstask-createcrea.md
- **Context:** Initial task creation

### 2026-04-05T16:04:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a83b15a9
- **Timestamp:** 2026-06-02T15:05:40Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Test file exists at tests/unit/create_task.bats
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/create_task.bats in: Test file exists at tests/unit/create_task.bats`
