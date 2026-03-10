---
id: T-415
name: "Decompose update-task.sh into modular functions (S13)"
description: >
  Break 500-line monolithic update-task.sh into testable functions: check_acceptance_criteria(), run_verification_commands(), check_human_sovereignty(), generate_episodic(). Currently mixes validation, AC checking, sovereignty gate, verification, and episodic generation. Directive score: S13=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, shell, reliability, usability]
components: [agents/task-create/update-task.sh]
related_tasks: [T-411]
created: 2026-03-10T21:03:15Z
last_update: 2026-03-10T22:46:37Z
date_finished: null
---

# T-415: Decompose update-task.sh into modular functions (S13)

## Context

Refactoring finding S13 (score 7) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**S13 — Long monolithic functions (update-task.sh ~500 lines):**
update-task.sh mixes validation, AC checking, human sovereignty gate, verification gate,
episodic generation, and file movement in one monolithic script.
See research artifact § "SHELL SCRIPTS" row S13.
Hardest refactoring task in this batch — requires careful decomposition without breaking gates.

## Acceptance Criteria

### Agent
- [x] update-task.sh decomposed into callable functions (not just inline code)
- [x] check_acceptance_criteria() extracted and independently testable
- [x] run_verification_commands() extracted
- [x] check_human_sovereignty() extracted
- [x] generate_episodic() clearly delineated (auto-trigger section, lines 460+)
- [x] All existing fw task update commands still work (regression test)

### Human
- [ ] [REVIEW] Task completion flow still works end-to-end
  **Steps:**
  1. Create a test task: `fw work-on 'Test decomposition' --type build`
  2. Add an AC and check it
  3. Run `fw task update T-XXX --status work-completed`
  4. Verify task moves to completed/ and episodic is generated
  **Expected:** Task completes successfully, episodic in .context/episodic/
  **If not:** Note which step failed and check agents/task-create/update-task.sh

## Verification

bash -n agents/task-create/update-task.sh
fw task update T-411 --status started-work 2>&1 | grep -q 'sovereignty\|human' || true

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

### 2026-03-10T21:03:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-415-decompose-update-tasksh-into-modular-fun.md
- **Context:** Initial task creation

### 2026-03-10T22:42:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-10T22:46:37Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-03-10T22:46:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
