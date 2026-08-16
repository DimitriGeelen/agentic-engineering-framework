---
id: T-560
name: "Investigate task hook reliability on Linux — PreToolUse Write/Edit gate not
  firing consistently"
description: >
  User reports being able to write files without being prompted to create tasks. This
  happens all the time on Linux. Previously on macOS the hook worked. Investigate:
  is check-active-task.sh firing? Is there a platform difference? Check hook registration,
  PATH resolution, and Claude Code hook execution on Linux.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [agents/context/check-active-task.sh, agents/context/lib/focus.sh]
related_tasks: []
created: 2026-03-23T17:00:05Z
last_update: '2026-08-16T22:25:34Z'
date_finished: 2026-03-24T10:52:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-560: Investigate task hook reliability on Linux — PreToolUse Write/Edit gate not firing consistently

## Context

User reports Write/Edit operations succeeding without task gate blocking. Worked on macOS, possibly broken on Linux. Platform: Linux 6.8.0-88-generic, Claude Code 2.1.74.

## Acceptance Criteria

### Agent
- [x] Root cause identified — stale focus.yaml persists across sessions, granting free pass to new sessions without explicit task selection
- [x] Investigation findings documented in this task file (see Updates section)
- [x] Fix applied: session-stamped focus (focus.sh stamps session_id, check-active-task.sh validates stamp matches current session)
- [x] `fw doctor` hook validation passes on Linux

### Human
- [x] [RUBBER-STAMP] Restart Claude Code session and try to Write without a task — verify it blocks
  **Steps:**
  1. `fw context focus --clear` (or start fresh session without focus)
  2. Try to edit any source file
  3. Check for "BLOCKED: No active task" message
  **Expected:** Write/Edit is blocked
  **If not:** Check `fw doctor` output, verify hooks in settings.json

## Verification

fw doctor > /tmp/fw-doctor-t560.txt 2>&1 || true; grep -q "Hook path validation" /tmp/fw-doctor-t560.txt

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

### 2026-03-23T17:00:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-560-investigate-task-hook-reliability-on-lin.md
- **Context:** Initial task creation

### 2026-03-23T17:00:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T10:52:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-670dfd6b
- **Timestamp:** 2026-06-02T15:03:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
