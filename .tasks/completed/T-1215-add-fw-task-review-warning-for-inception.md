---
id: T-1215
name: "Add fw task review warning for inception tasks without Recommendation section
  (T-1213 GO)"
description: >
  Add fw task review warning for inception tasks without Recommendation section (T-1213
  GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/review.sh]
related_tasks: []
created: 2026-04-13T09:20:35Z
last_update: '2026-08-16T22:24:26Z'
date_finished: 2026-04-13T09:21:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
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
  - ts: '2026-08-16T22:24:26Z'
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

# T-1215: Add fw task review warning for inception tasks without Recommendation section (T-1213 GO)

## Context

T-1213 GO, RC-2. `fw task review` creates the review marker but doesn't check if inception tasks
have a substantive `## Recommendation`. Add a warning (not a block) so the agent knows the human
will see a bare approvals card.

## Acceptance Criteria

### Agent
- [x] `lib/review.sh` checks for `## Recommendation` on inception tasks
- [x] Warning emitted when recommendation is missing/empty (not blocking)
- [x] Existing review flow still works (marker created, URL emitted)

## Verification

# review.sh still sources correctly
grep -q 'emit_review' lib/review.sh

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

### 2026-04-13T09:20:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1215-add-fw-task-review-warning-for-inception.md
- **Context:** Initial task creation

### 2026-04-13T09:21:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fca4668c
- **Timestamp:** 2026-06-02T14:55:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
