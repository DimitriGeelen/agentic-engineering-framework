---
id: T-634
name: "Deterministic human review — shared _emit_review helper, auto-emit on partial-complete
  and inception decide, /review skill"
description: >
  Deterministic human review — shared _emit_review helper, auto-emit on partial-complete
  and inception decide, /review skill

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-27T06:53:56Z
last_update: '2026-08-16T22:25:35Z'
date_finished: 2026-03-27T08:35:26Z
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
  - ts: '2026-08-16T22:25:35Z'
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

# T-634: Deterministic human review — shared _emit_review helper, auto-emit on partial-complete and inception decide, /review skill

## Context

Four-layer enforcement: when a task has human ACs or a GO decision, the framework must always present review info (URL, QR, artifacts) — not rely on agent discipline. Builds on T-631 (`fw task review`), T-633 (auto-link artifacts). Related: T-325 (human AC handoffs), T-372 (blind completion pattern).

## Acceptance Criteria

### Agent
- [x] Shared `_emit_review()` bash function in `lib/review.sh` (URL detection, QR, artifacts, human AC count)
- [x] `fw inception decide` calls `_emit_review()` after recording decision
- [x] `fw task update --status work-completed` calls `_emit_review()` when human ACs are pending (partial-complete)
- [x] `fw task review` refactored to use shared `_emit_review()`
- [x] `/review` skill created — lists all tasks with pending human ACs, calls `fw task review` for each

### Human
- [x] [RUBBER-STAMP] Verify review output appears on partial-complete
  **Steps:**
  1. Pick any task with human ACs and run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task update T-633 --status work-completed`
  2. Observe output after "Partial-complete" message
  **Expected:** Review URL, QR code, and research artifacts auto-displayed
  **If not:** Check that `update-task.sh` sources `lib/review.sh` and calls `_emit_review`

## Verification

grep -q 'emit_review' lib/review.sh
grep -q 'emit_review' lib/inception.sh
grep -q 'emit_review' agents/task-create/update-task.sh
test -f .claude/commands/review.md

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

### 2026-03-27T06:53:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-634-deterministic-human-review--shared-emitr.md
- **Context:** Initial task creation

### 2026-03-27T08:35:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b1319115
- **Timestamp:** 2026-06-02T15:04:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
