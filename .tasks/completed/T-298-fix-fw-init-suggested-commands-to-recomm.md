---
id: T-298
name: "Fix fw init suggested commands to recommend fw work-on"
description: >
  fw init prints Next steps recommending 'fw task create --name ...' which hangs without --description flag (O-007) and doesn't set focus even with --start (O-008). Fix: change step 4 to recommend 'fw work-on "My first task" --type build' which is the only end-to-end working path. Location: lib/init.sh echo block at end of do_init(). Source: T-294 simulation O-007.

status: work-completed
workflow_type: build
owner: agent
horizon: next
tags: []
components: [agents/context/lib/init.sh]
related_tasks: [T-294]
created: 2026-03-04T16:13:56Z
last_update: 2026-03-04T18:17:56Z
date_finished: 2026-03-04T18:17:56Z
---

# T-298: Fix fw init suggested commands to recommend fw work-on

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] First-session welcome suggests `fw work-on` instead of `fw task create`
- [x] Removed redundant "Set focus" step (fw work-on handles it)

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

### 2026-03-04T16:13:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-298-fix-fw-init-suggested-commands-to-recomm.md
- **Context:** Initial task creation

### 2026-03-04T18:11:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:17:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
