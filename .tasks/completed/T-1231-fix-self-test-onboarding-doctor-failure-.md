---
id: T-1231
name: "Fix self-test onboarding doctor failure — diagnose and resolve pre-existing
  issue"
description: >
  Fix self-test onboarding doctor failure — diagnose and resolve pre-existing issue

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T13:53:13Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-13T14:03:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1231: Fix self-test onboarding doctor failure — diagnose and resolve pre-existing issue

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Root cause: inherited PROJECT_ROOT env var from framework session causes doctor to validate wrong project
- [x] Fix: unset PROJECT_ROOT before running doctor in self-test subshell
- [x] `fw self-test onboarding` passes (5/5 phases, 0 failures)

## Verification

# Verify the fix is in the test file
grep -q 'unset PROJECT_ROOT' tests/e2e/onboarding-test.sh

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

### 2026-04-13T13:53:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1231-fix-self-test-onboarding-doctor-failure-.md
- **Context:** Initial task creation

### 2026-04-13T14:03:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Root cause: inherited PROJECT_ROOT. Fix: unset in self-test subshell. 5/5 phases pass.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dd6c99f5
- **Timestamp:** 2026-06-02T14:56:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
