---
id: T-694
name: "Approval file lifecycle — cleanup resolved files older than 7 days, reset notified
  tracker on session init"
description: >
  Approval file lifecycle — cleanup resolved files older than 7 days, reset notified
  tracker on session init

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-008]
related_tasks: []
created: 2026-03-28T23:54:46Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-28T23:56:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
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

# T-694: Approval file lifecycle — cleanup resolved files older than 7 days, reset notified tracker on session init

## Context

T-691 added stale pending cleanup (>2h) and approval notifications. This task completes the lifecycle: (1) resolved files >7 days are cleaned up (bypass-log.yaml has the permanent record), (2) `.approval-notified` tracker is reset on `checkpoint.sh reset` (session init).

## Acceptance Criteria

### Agent
- [x] Resolved approval files older than 7 days auto-cleaned in checkpoint.sh post-tool
- [x] `.approval-notified` cleared in `checkpoint.sh reset` command
- [x] bypass-log.yaml remains as permanent audit trail (not cleaned)

## Verification

grep -q 'resolved.*STALE_RESOLVED_AGE\|STALE_RESOLVED' agents/context/checkpoint.sh
grep -q 'approval-notified' agents/context/checkpoint.sh

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

### 2026-03-28T23:54:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-694-approval-file-lifecycle--cleanup-resolve.md
- **Context:** Initial task creation

### 2026-03-28T23:56:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3fe35744
- **Timestamp:** 2026-06-02T15:04:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
