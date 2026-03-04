---
id: T-304
name: "Build opt-out first-run experience after fw init"
description: >
  After fw init completes, automatically run a guided first-governance-cycle walkthrough (5 steps: create task, make change, commit with traceability, run audit, generate handover). Opt-out via --no-first-run flag on fw init. Shows the user the framework doing something useful immediately — closes the 'cargo run gap' from DX comparison. Prints each step, executes it, validates result. Source: T-294 DX comparison, Area 6B.

status: started-work
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:27:33Z
last_update: 2026-03-04T18:40:46Z
date_finished: null
---

# T-304: Build opt-out first-run experience after fw init

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `lib/first-run.sh` created with 3-step walkthrough (doctor, context init, next steps)
- [x] `fw init` calls first-run automatically in interactive mode
- [x] `--no-first-run` flag skips walkthrough
- [x] Non-interactive (piped/CI) skips walkthrough, shows static next steps

### Human
- [ ] Walkthrough output is clear and encouraging for new users

## Verification

test -f /opt/999-Agentic-Engineering-Framework/lib/first-run.sh
grep -q "first_run" /opt/999-Agentic-Engineering-Framework/lib/init.sh
grep -q "no-first-run" /opt/999-Agentic-Engineering-Framework/lib/init.sh

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

### 2026-03-04T16:27:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-304-build-opt-out-first-run-experience-after.md
- **Context:** Initial task creation

### 2026-03-04T18:40:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
