---
id: T-692
name: "Learning capture prompt for bugfix tasks — structural nudge in update-task.sh
  when completing fix tasks without a learning entry"
description: >
  Learning capture prompt for bugfix tasks — structural nudge in update-task.sh when
  completing fix tasks without a learning entry

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-03-28T23:47:17Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-28T23:49:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-692: Learning capture prompt for bugfix tasks — structural nudge in update-task.sh when completing fix tasks without a learning entry

## Context

G-016: 72% of bugfix tasks produce zero learning entries. The Bug-Fix Learning Checkpoint practice in CLAUDE.md is behavioral (agent self-governs). This adds a structural nudge: when completing a task whose name contains "fix", check if any learning references that task ID. If not, emit a prompt.

## Acceptance Criteria

### Agent
- [x] update-task.sh checks for "fix" in task name on work-completed
- [x] Checks learnings.yaml for entries referencing the task ID
- [x] Emits a visible prompt when no learning exists for a fix task
- [x] Prompt is advisory (non-blocking) — does not prevent completion
- [x] Does not fire for non-fix tasks

## Verification

grep -q 'Learning capture check' agents/task-create/update-task.sh
grep -q 'learnings.yaml' agents/task-create/update-task.sh

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

### 2026-03-28T23:47:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-692-learning-capture-prompt-for-bugfix-tasks.md
- **Context:** Initial task creation

### 2026-03-28T23:49:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bd6f874c
- **Timestamp:** 2026-06-02T15:04:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
