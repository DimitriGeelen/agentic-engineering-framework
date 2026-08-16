---
id: T-651
name: "Agent/Task tool gate — add Agent|TaskCreate to check-active-task matcher"
description: >
  T-630 GO build task 2: Add Agent|TaskCreate|TaskUpdate to check-active-task.sh PreToolUse
  matcher in settings.json. Zero code changes to check-active-task.sh — empty file_path
  falls through to task-exists check. Blocked by B-005 (settings.json protection —
  human must update). Related: T-630, T-650.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T09:44:55Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-28T09:45:43Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-651: Agent/Task tool gate — add Agent|TaskCreate to check-active-task matcher

## Context

T-630 GO: Universal task gate. Spike 2 proved check-active-task.sh already handles empty file_path correctly — zero code changes needed. Only settings.json matcher update required. B-005 blocks agent edits to settings.json.

## Acceptance Criteria

### Agent
- [x] Verified check-active-task.sh handles Agent/TaskCreate tools (empty file_path falls through to task-exists check)
- [x] Documented required settings.json change

### Human
- [x] [RUBBER-STAMP] Add Agent|TaskCreate matcher to settings.json
  **Steps:**
  1. Open `.claude/settings.json` in editor
  2. Add new PreToolUse entry: `{"matcher": "Agent|TaskCreate|TaskUpdate", "hooks": [{"type": "command", "command": "fw hook check-active-task"}]}`
  3. Restart Claude Code session (hooks snapshot at session start)
  4. Verify: try Agent tool without a task — should be blocked
  **Expected:** Agent/TaskCreate/TaskUpdate blocked without active task, allowed with task
  **If not:** Check that the matcher format is correct (nested hooks array)

## Verification

# No verification needed — settings.json change is human-only (B-005)

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

### 2026-03-28T09:44:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-651-agenttask-tool-gate--add-agenttaskcreate.md
- **Context:** Initial task creation

### 2026-03-28T09:45:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5d579954
- **Timestamp:** 2026-06-02T15:04:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
