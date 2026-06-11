---
id: T-973
name: "Review-before-decide gate — fw inception decide requires fw task review first"
description: >
  Review-before-decide gate — fw inception decide requires fw task review first

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-06T19:53:57Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-06T19:58:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
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
---

# T-973: Review-before-decide gate — fw inception decide requires fw task review first

## Context

Agent in freshly initialized WorkshopDesigner project gave raw `fw inception decide` command instead of using `fw task review`. T-679 rule exists but is advisory-only. Need structural gate: `fw inception decide` refuses unless `fw task review` was called first (marker file). Also: `fw task review` must output the full decision command alongside QR for inception tasks. Related: T-557, T-679, G-019.

## Acceptance Criteria

### Agent
- [x] `review.sh` creates `.context/working/.reviewed-T-XXX` marker when `emit_review()` runs
- [x] `review.sh` outputs full `fw inception decide` command for inception tasks alongside QR code
- [x] `inception.sh` `do_inception_decide()` checks for marker and blocks with helpful message if missing
- [x] Marker is cleaned up after decision is recorded
- [x] Verification commands pass

## Verification

grep -q '.reviewed-' .agentic-framework/lib/review.sh
grep -q '.reviewed-' .agentic-framework/lib/inception.sh
grep -q 'bin/fw inception decide' .agentic-framework/lib/review.sh

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

### 2026-04-06T19:53:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-973-review-before-decide-gate--fw-inception-.md
- **Context:** Initial task creation

### 2026-04-06T19:58:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Gate implemented and tested

## Reviewer Verdict (v1.5)

- **Scan ID:** R-880a3b75
- **Timestamp:** 2026-06-02T15:05:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
