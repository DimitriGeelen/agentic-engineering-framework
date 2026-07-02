---
id: T-321
name: "Register unregistered components and session cleanup"
description: >
  Register block-plan-mode.sh and test-onboarding.sh in fabric. Fix stale handover.

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-04T22:39:14Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-04T22:42:23Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-321: Register unregistered components and session cleanup

## Context

Fabric drift detected 2 unregistered components. Register and fill cards.

## Acceptance Criteria

### Agent
- [x] `block-plan-mode.sh` registered with purpose and dependencies
- [x] `test-onboarding.sh` registered with purpose and dependencies
- [x] `fw fabric drift` shows no newly unregistered components (16 pre-existing remain)

## Verification

# Both cards exist
test -f .fabric/components/agents-context-block-plan-mode.yaml
test -f .fabric/components/agents-onboarding-test-test-onboarding.yaml
# Cards have purpose filled
grep -q "PreToolUse hook" .fabric/components/agents-context-block-plan-mode.yaml
grep -q "End-to-end onboarding" .fabric/components/agents-onboarding-test-test-onboarding.yaml

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

### 2026-03-04T22:39:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-321-register-unregistered-components-and-ses.md
- **Context:** Initial task creation

### 2026-03-04T22:42:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a8a20090
- **Timestamp:** 2026-06-02T15:02:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
