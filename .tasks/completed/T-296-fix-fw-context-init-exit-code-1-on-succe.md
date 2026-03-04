---
id: T-296
name: "Fix fw context init exit code 1 on success"
description: >
  fw context init returns exit code 1 even on successful initialization. Root cause: do_init() in agents/context/lib/init.sh ends without explicit return 0 — last command exit code leaks through. Fix: add return 0 at end of function. Source: T-294 simulation O-005.

status: work-completed
workflow_type: build
owner: agent
horizon: next
tags: []
components: [agents/context/lib/init.sh]
related_tasks: [T-294]
created: 2026-03-04T16:06:35Z
last_update: 2026-03-04T18:17:52Z
date_finished: 2026-03-04T18:17:52Z
---

# T-296: Fix fw context init exit code 1 on success

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw context init` exits with code 0 on success
- [x] Root cause: SIGPIPE from `head -1` pipeline with `pipefail` + missing `return 0`

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

### 2026-03-04T16:06:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-296-fix-fw-context-init-exit-code-1-on-succe.md
- **Context:** Initial task creation

### 2026-03-04T18:17:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:17:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
