---
id: T-642
name: "emit_review type parameter — route inception to /inception, tasks to /tasks"
description: >
  emit_review type parameter — route inception to /inception, tasks to /tasks

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/review.sh]
related_tasks: []
created: 2026-03-27T12:18:57Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-27T12:20:56Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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

# T-642: emit_review type parameter — route inception to /inception, tasks to /tasks

## Context

T-636 Phase 2. emit_review() hardcodes `/tasks/T-XXX#human-ac` for the review URL. Inception tasks should route to `/inception/T-XXX` instead. Detect workflow_type from task frontmatter and adjust URL.

## Acceptance Criteria

### Agent
- [x] emit_review() detects workflow_type from task frontmatter
- [x] Inception tasks route to /inception/T-XXX
- [x] Build/other tasks still route to /tasks/T-XXX#human-ac
- [x] Banner label adapts: "Human AC Review" for builds, "Inception Review" for inception

## Verification

grep -q 'inception' lib/review.sh

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

### 2026-03-27T12:18:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-642-emitreview-type-parameter--route-incepti.md
- **Context:** Initial task creation

### 2026-03-27T12:20:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f0faf271
- **Timestamp:** 2026-06-02T15:04:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
