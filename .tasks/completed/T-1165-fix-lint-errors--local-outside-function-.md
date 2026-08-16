---
id: T-1165
name: "Fix lint errors — local outside function in handover.sh"
description: >
  Fix lint errors — local outside function in handover.sh

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T13:19:21Z
last_update: '2026-08-16T22:24:24Z'
date_finished: 2026-04-12T13:22:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1165: Fix lint errors — local outside function in handover.sh

## Context

Shellcheck SC2168 error: `local _push_failed=false` on line 756 of `agents/handover/handover.sh` is outside any function (in main script body). Same issue in vendored copy.

## Acceptance Criteria

### Agent
- [x] SC2168 lint error fixed in `agents/handover/handover.sh`
- [x] Vendored copy synced
- [x] `fw test lint` shows 0 errors (was 2)

## Verification

bash -c '! shellcheck -S error agents/handover/handover.sh 2>&1 | grep -q SC2168'

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

### 2026-04-12T13:19:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1165-fix-lint-errors--local-outside-function-.md
- **Context:** Initial task creation

### 2026-04-12T13:22:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d85db4b3
- **Timestamp:** 2026-06-02T14:55:37Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash -c '! shellcheck -S error agents/handover/handover.sh 2>&1 | grep -q SC2168'`
