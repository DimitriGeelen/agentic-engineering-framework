---
id: T-1166
name: "Upgrade consumer projects to v1.5.413 — 13 projects behind"
description: >
  Upgrade consumer projects to v1.5.413 — 13 projects behind

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T13:35:14Z
last_update: '2026-08-16T22:24:24Z'
date_finished: 2026-04-12T13:43:06Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1166: Upgrade consumer projects to v1.5.413 — 13 projects behind

## Context

`fw doctor` shows 11 consumer projects behind on version v1.5.413. Run `fw upgrade` on each to sync framework shims, hooks, and scripts.

## Acceptance Criteria

### Agent
- [x] All 11 consumer projects upgraded to current version
- [x] `fw doctor` shows no version warnings for consumer projects

## Verification

bash -c 'bin/fw doctor 2>&1 | grep "WARN.*v1.5" | wc -l | grep -q "^0$"'

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

### 2026-04-12T13:35:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1166-upgrade-consumer-projects-to-v15413--13-.md
- **Context:** Initial task creation

### 2026-04-12T13:43:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7158ec28
- **Timestamp:** 2026-06-02T14:55:37Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash -c 'bin/fw doctor 2>&1 | grep "WARN.*v1.5" | wc -l | grep -q "^0$"'`
