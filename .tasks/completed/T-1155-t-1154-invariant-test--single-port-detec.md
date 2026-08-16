---
id: T-1155
name: "T-1154 invariant test — single-port-detection lint guard"
description: >
  T-1154 invariant test — single-port-detection lint guard

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T11:45:12Z
last_update: '2026-08-16T22:24:24Z'
date_finished: 2026-04-12T11:46:15Z
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

# T-1155: T-1154 invariant test — single-port-detection lint guard

## Context

Invariant test for T-1154. Guards against inline port detection re-emerging in review.sh, verify-acs.sh, or other scripts. Per T-1105 chokepoint+invariant-test discipline.

## Acceptance Criteria

### Agent
- [x] `tests/lint/single-port-detection.bats` exists with 5+ tests
- [x] All bats tests pass

## Verification

bash -c 'test -f tests/lint/single-port-detection.bats'
bash -c 'cd /opt/999-Agentic-Engineering-Framework && bats tests/lint/single-port-detection.bats'

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

### 2026-04-12T11:45:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1155-t-1154-invariant-test--single-port-detec.md
- **Context:** Initial task creation

### 2026-04-12T11:46:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9863cd0e
- **Timestamp:** 2026-06-02T14:55:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
