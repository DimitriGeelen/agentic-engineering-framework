---
id: T-517
name: "Implement fw dispatch SSH-based cross-machine communication"
description: >
  Implement fw dispatch SSH-based cross-machine communication

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-21T16:04:03Z
last_update: 2026-03-21T16:04:03Z
date_finished: null
---

# T-517: Implement fw dispatch SSH-based cross-machine communication

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] fw dispatch command implemented (~130 lines bash in lib/dispatch.sh)
- [x] fw bus receive command implemented (~35 lines bash in lib/bus.sh)
- [x] --remote flag added to fw bus post
- [x] Uses ~/.ssh/config for host resolution
- [x] Documentation updated in CLAUDE.md
- [x] Syntax validation passes (bash -n)

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

### 2026-03-21T16:04:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /home/dimitri-mint-dev/.agentic-framework/.tasks/active/T-517-implement-fw-dispatch-ssh-based-cross-ma.md
- **Context:** Initial task creation
