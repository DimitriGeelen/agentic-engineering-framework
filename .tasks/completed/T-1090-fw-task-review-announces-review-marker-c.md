---
id: T-1090
name: "fw task review announces review-marker creation as unblock for fw inception
  decide"
description: >
  T-1084 follow-up: emit_review in lib/review.sh creates .context/working/.reviewed-TASK
  as an invisible side effect. Agents had to dig through source to discover that running
  fw task review unblocks fw inception decide. Add an explicit line to the output
  announcing the marker creation and its purpose (T-973 gate unblock).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-11T10:47:21Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-11T10:48:22Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
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

# T-1090: fw task review announces review-marker creation as unblock for fw inception decide

## Context

T-1084 follow-up. `emit_review` in `lib/review.sh:135-136` silently creates `.context/working/.reviewed-TASK` — that marker is the T-973 unblock prereq for `fw inception decide`, but the output doesn't mention it. Agents had to dig through source to discover that `fw task review` was the unblock for a seemingly unrelated gate. Print one line announcing the marker and its purpose.

## Acceptance Criteria

### Agent
- [x] `emit_review` prints a one-line notice after creating the review marker, stating the marker path and that it unblocks `fw inception decide` (T-973 gate).
- [x] Mirrored to `.agentic-framework/lib/review.sh`.
- [x] Running `bin/fw task review T-1090` on this task emits output containing the marker announcement string.

## Verification

grep -q "\.reviewed-" lib/review.sh
grep -q "unblocks" lib/review.sh
grep -q "\.reviewed-" .agentic-framework/lib/review.sh
grep -q "unblocks" .agentic-framework/lib/review.sh

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

### 2026-04-11T10:47:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1090-fw-task-review-announces-review-marker-c.md
- **Context:** Initial task creation

### 2026-04-11T10:48:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9ebff988
- **Timestamp:** 2026-06-02T14:55:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
