---
id: T-1203
name: "Refactor update-task.sh bare fw commands to use _emit_user_command (T-1146
  GO)"
description: >
  Refactor update-task.sh bare fw commands to use _emit_user_command (T-1146 GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T08:08:56Z
last_update: '2026-08-16T22:24:25Z'
date_finished: 2026-04-13T08:12:14Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1203: Refactor update-task.sh bare fw commands to use _emit_user_command (T-1146 GO)

## Context

T-1146 GO identified 40 bare `fw` command output sites across 7 files. update-task.sh has 7 sites
that emit bare `fw` commands instead of using `_emit_user_command()` (from lib/paths.sh). These bare
commands are not copy-pasteable from arbitrary directories and use `fw` instead of `bin/fw`.
Related: T-1154 (watchtower URL helper), T-1201 (review.sh terminal overflow fix), T-609 (copy-paste rule).

## Acceptance Criteria

### Agent
- [x] All bare `fw` commands in update-task.sh use `_emit_user_command()` or `_fw_cmd()`
- [x] No bare `echo ".*fw ` patterns remain in update-task.sh (except comments)
- [x] update-task.sh sources paths.sh (for `_emit_user_command` availability)
- [x] Lint test: invariant test verifies no bare `fw` in guidance output

## Verification

# Invariant test passes
bats tests/lint/no-bare-fw-in-gate-scripts.bats
# paths.sh is sourced
grep -q 'source.*paths.sh' agents/task-create/update-task.sh

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

### 2026-04-13T08:08:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1203-refactor-update-tasksh-bare-fw-commands-.md
- **Context:** Initial task creation

### 2026-04-13T08:12:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bd5810c6
- **Timestamp:** 2026-06-02T14:55:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
