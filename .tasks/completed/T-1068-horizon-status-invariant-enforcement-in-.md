---
id: T-1068
name: "Horizon-status invariant enforcement in update-task.sh"
description: >
  Add auto-sync logic: started-work auto-sets horizon:now, horizon next/later auto-demotes
  started-work to captured. Update tests and CLAUDE.md. Origin: T-1067 GO.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-08T10:32:30Z
last_update: '2026-08-16T22:24:21Z'
date_finished: 2026-04-08T10:36:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1068: Horizon-status invariant enforcement in update-task.sh

## Context

Origin: T-1067 GO. Research: `docs/reports/T-1067-horizon-status-invariants.md`

## Acceptance Criteria

### Agent
- [x] Invariant 1: `--status started-work` auto-sets horizon to `now` with info message
- [x] Invariant 2: `--horizon next/later` on a `started-work` task auto-demotes status to `captured` with info message
- [x] Existing test 7 updated for new invariant behavior (sets captured first to test pure horizon change)
- [x] New tests cover both invariant paths (4 tests: promote, demote-later, demote-next, no-demote-issues)
- [x] All update_task.bats tests pass (15/15)
- [x] CLAUDE.md documents the invariant rules (Horizon section)

## Verification

bats tests/unit/update_task.bats

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

### 2026-04-08T10:32:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1068-horizon-status-invariant-enforcement-in-.md
- **Context:** Initial task creation

### 2026-04-08T10:36:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3cc7e2e1
- **Timestamp:** 2026-06-02T14:54:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
