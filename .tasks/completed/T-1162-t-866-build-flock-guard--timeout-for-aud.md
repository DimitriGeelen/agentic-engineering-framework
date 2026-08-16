---
id: T-1162
name: "T-866 build: flock guard + timeout for audit cron — prevent zombie accumulation"
description: >
  T-866 build: flock guard + timeout for audit cron — prevent zombie accumulation

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-004]
related_tasks: []
created: 2026-04-12T12:14:36Z
last_update: '2026-08-16T22:24:24Z'
date_finished: 2026-04-12T12:16:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
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
  - ts: '2026-08-16T22:24:24Z'
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

# T-1162: T-866 build: flock guard + timeout for audit cron — prevent zombie accumulation

## Context

Build from T-866 GO. Audit cron runs every 15 min. When an audit takes >15 min (measured 4 min), the next cron fires before the last finishes — zombie accumulation. Fix: flock guard ensures only one audit runs at a time, timeout kills long-running audits.

## Acceptance Criteria

### Agent
- [x] `audit.sh --cron` uses flock to prevent concurrent runs
- [x] Timeout configurable via `FW_AUDIT_TIMEOUT` (default 600s)
- [x] Stale lock files cleaned up automatically

## Verification

bash -c 'grep -q "flock" agents/audit/audit.sh'
bash -c 'grep -q "FW_AUDIT_TIMEOUT\|AUDIT_TIMEOUT" agents/audit/audit.sh'

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

### 2026-04-12T12:14:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1162-t-866-build-flock-guard--timeout-for-aud.md
- **Context:** Initial task creation

### 2026-04-12T12:16:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d68165a4
- **Timestamp:** 2026-06-02T14:55:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
