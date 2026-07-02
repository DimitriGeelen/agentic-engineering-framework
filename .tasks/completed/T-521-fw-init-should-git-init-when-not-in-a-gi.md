---
id: T-521
name: "fw init should git init when not in a git repo"
description: >
  fw init doesn't create a git repo. Git hooks, traceability, and commit-msg enforcement
  all require git. Should git init + initial commit if not already in a repo. Found
  during TermLink install test.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-17T22:39:15Z
last_update: '2026-06-11T22:24:23Z'
date_finished: 2026-03-17T22:45:38Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:23Z'
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
---

# T-521: fw init should git init when not in a git repo

## Context

`fw init` should auto-create a git repo if not already in one. Git is required for hooks, traceability, and commit-msg enforcement.

## Acceptance Criteria

### Agent
- [x] `lib/init.sh` calls `git init` when target is not in a git repo
- [x] `bash -n lib/init.sh` passes

## Verification

bash -n lib/init.sh
grep -q "git init" lib/init.sh

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

### 2026-03-17T22:39:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-521-fw-init-should-git-init-when-not-in-a-gi.md
- **Context:** Initial task creation

### 2026-03-17T22:45:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b06268f4
- **Timestamp:** 2026-06-02T15:03:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
