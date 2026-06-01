---
id: T-556
name: "Handover commit attribution — use session ID not active task ID"
description: >
  fw handover --commit attributes the commit to whatever task is in focus (e.g. T-012: Session handover). Handovers are session-level, not task-level. Change to use T-012 housekeeping prefix or session ID (S-YYYY-MMDD-HHMM). Low effort — change commit message format in handover.sh. Origin: T-549 OpenClaw eval — handover committed under T-012 (TermLink learnings task).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:21:22Z
last_update: 2026-03-27T19:13:26Z
date_finished: 2026-03-27T19:13:26Z
---

# T-556: Handover commit attribution — use session ID not active task ID

## Context

`_resolve_commit_task()` in `agents/handover/handover.sh:12-51` resolves the task ID for handover commits via a 6-step cascade: `--task` flag → T-012 → slug match → auto-create → **focused task** → T-000. Step 5 (focused task, line 40-48) is the bug: when T-012 doesn't exist in a consumer project, handover commits get attributed to the currently focused work task (e.g., "T-549: Session handover S-..."), polluting that task's git log. Handovers are session-level operations and should never be attributed to work tasks.

**Scope:** Modify `_resolve_commit_task()` only. No changes to commit format, git agent, or handover template.

## Acceptance Criteria

### Agent

- [x] `_resolve_commit_task()` removes the focused-task fallback (lines 40-48) — handover commits never use the task from `focus.yaml`
- [x] When no T-012 or handover-slug task exists, auto-creation (lines 28-37) remains the primary fallback — a dedicated handover task is always created rather than borrowing a work task
- [x] The T-000 absolute fallback (line 50) remains as last resort after auto-creation failure
- [x] Both normal-mode (line 646) and checkpoint-mode (line 155) commit messages use the resolved handover task, not any work task
- [x] `handover.sh --task T-XXX` override still works (line 13-14 unchanged)

## Verification

# Focused task fallback must not exist in _resolve_commit_task
! grep -A5 'focus_file.*focus.yaml' agents/handover/handover.sh | grep -q 'COMMIT_TASK=.*focused'
# T-000 fallback still exists
grep -q 'COMMIT_TASK="T-000"' agents/handover/handover.sh
# --task flag still accepted
grep -q '\-\-task.*COMMIT_TASK' agents/handover/handover.sh
# Auto-create path still exists
grep -q 'Auto-created handover task' agents/handover/handover.sh
# Script parses without errors
bash -n agents/handover/handover.sh

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

### 2026-03-23T16:21:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-556-handover-commit-attribution--use-session.md
- **Context:** Initial task creation

### 2026-03-26T16:03:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27T19:13:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
