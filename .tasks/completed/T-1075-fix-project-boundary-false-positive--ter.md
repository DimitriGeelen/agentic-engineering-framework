---
id: T-1075
name: "Fix project boundary false positive — TermLink commands inside loops/pipes"
description: >
  Fix project boundary false positive — TermLink commands inside loops/pipes

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-09T13:06:31Z
last_update: '2026-08-16T22:24:22Z'
date_finished: 2026-04-09T13:08:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
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
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1075: Fix project boundary false positive — TermLink commands inside loops/pipes

## Context

R-037 concern. TermLink exception in check-project-boundary.sh only matches commands starting with `termlink`. Commands inside loops (`for n in ...; do termlink pty inject ...`) are blocked because the loop starts with `for`, not `termlink`. Discovered during T-1071 consumer upgrades.

## Acceptance Criteria

### Agent
- [x] TermLink exception matches commands containing `termlink` anywhere (not just at start)
- [x] Existing boundary tests still pass (23/23 original tests)
- [x] TermLink commands in loops/pipes are allowed (5 new tests: start, for-loop, semicolon, &&, fw termlink)

## Verification

bats tests/integration/check_project_boundary.bats
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-09T13:06:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1075-fix-project-boundary-false-positive--ter.md
- **Context:** Initial task creation

### 2026-04-09T13:08:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d814fc67
- **Timestamp:** 2026-06-02T14:54:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
