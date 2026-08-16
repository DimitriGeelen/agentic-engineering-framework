---
id: T-862
name: "Fix audit performance for pre-push — fast path for push hook"
description: >
  Fix audit performance for pre-push — fast path for push hook

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/git/lib/hooks.sh]
related_tasks: []
created: 2026-04-04T19:57:14Z
last_update: '2026-08-16T22:25:41Z'
date_finished: 2026-04-04T21:58:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
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
  - ts: '2026-08-16T22:25:41Z'
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

# T-862: Fix audit performance for pre-push — fast path for push hook

## Context

Full audit takes >90s with 124 active tasks (7 loops × 15 Python calls). Pre-push hook runs full audit, blocking git push with timeout. Fix: add `--sections` filter to pre-push, running only structure + task-compliance + git-traceability (skip discovery, quality, observations).

## Acceptance Criteria

### Agent
- [x] Pre-push hook passes `--section structure` flag to audit to run fast subset
- [x] `audit.sh --section structure` completes in ~11s (vs >90s for full audit)
- [x] Full audit (no --section) still runs all checks

## Verification

# pre-push hook uses --section flag
grep -q 'section structure' .git/hooks/pre-push

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

### 2026-04-04T19:57:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-862-fix-audit-performance-for-pre-push--fast.md
- **Context:** Initial task creation

### 2026-04-04T21:58:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0fe71209
- **Timestamp:** 2026-06-02T15:05:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
