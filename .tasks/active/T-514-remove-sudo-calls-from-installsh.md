---
id: T-514
name: "Remove sudo calls from install.sh"
description: >
  Remove sudo calls from install.sh

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-21T15:59:21Z
last_update: 2026-03-21T15:59:21Z
date_finished: null
---

# T-514: Remove sudo calls from install.sh

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] No sudo calls in install.sh
- [x] link_fw uses ~/.local/bin with PATH instruction
- [x] MODIFY_PATH env var added for CI/automation with idempotency
- [x] install.sh syntax valid (bash -n)
- [x] Exit 0 on success

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

### 2026-03-21T15:59:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /home/dimitri-mint-dev/.agentic-framework/.tasks/active/T-514-remove-sudo-calls-from-installsh.md
- **Context:** Initial task creation
