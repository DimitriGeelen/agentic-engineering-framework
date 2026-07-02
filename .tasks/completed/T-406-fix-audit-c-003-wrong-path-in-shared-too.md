---
id: T-406
name: "Fix audit C-003 wrong path in shared-tooling mode (OneDev #1)"
description: >
  Fix audit C-003 check using $PROJECT_ROOT/agents/ instead of $FRAMEWORK_ROOT/agents/.
  In shared-tooling mode (brew install), consumer projects don't have local agents/
  dir.
  OneDev issue #1.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-10T13:47:48Z
last_update: '2026-06-11T22:24:20Z'
date_finished: 2026-03-10T13:51:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-406: Fix audit C-003 wrong path in shared-tooling mode (OneDev #1)

## Context

OneDev issue #1: C-003 audit check used `$PROJECT_ROOT/agents/context/checkpoint.sh` — wrong in shared-tooling mode where agents live under `$FRAMEWORK_ROOT`. All other agent path references in audit.sh already use `$FRAMEWORK_ROOT`. This was the sole outlier.

## Acceptance Criteria

### Agent
- [x] C-003 check uses `$FRAMEWORK_ROOT` instead of `$PROJECT_ROOT`
- [x] No remaining `$PROJECT_ROOT/agents/` references in audit.sh
- [x] C-003 passes in embedded mode (framework repo)
- [x] No regression — audit passes with 0 FAIL

## Verification

# C-003 uses FRAMEWORK_ROOT not PROJECT_ROOT
grep -q 'FRAMEWORK_ROOT/agents/context/checkpoint.sh' agents/audit/audit.sh
! grep -q 'PROJECT_ROOT/agents/' agents/audit/audit.sh

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

### 2026-03-10T13:47:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-406-fix-audit-c-003-wrong-path-in-shared-too.md
- **Context:** Initial task creation

### 2026-03-10T13:51:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-29781189
- **Timestamp:** 2026-06-02T15:02:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
