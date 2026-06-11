---
id: T-807
name: "Unit tests for lib/costs.sh token tracking"
description: >
  Unit tests for lib/costs.sh token tracking

status: work-completed
workflow_type: test
owner: human
horizon:
tags: []
components: [tests/unit/lib_costs.bats]
related_tasks: []
created: 2026-04-03T20:00:38Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-04-12T07:55:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
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

# T-807: Unit tests for lib/costs.sh token tracking

## Context

Add bats unit tests for `lib/costs.sh` (T-801). Tests cover `_costs_jsonl_dir` path computation, `costs_main` routing, Python parsing with JSONL fixtures, and edge cases (empty dir, no data, malformed JSON).

## Acceptance Criteria

### Agent
- [x] Test file `tests/unit/lib_costs.bats` exists and follows project test conventions
- [x] Tests cover `_costs_jsonl_dir` path computation
- [x] Tests cover `costs_main` routing (summary, session, current, help, unknown)
- [x] Tests cover Python JSONL parsing with fixture data
- [x] Tests cover edge cases: empty directory, no JSONL files, malformed JSON lines
- [x] All tests pass: `bats tests/unit/lib_costs.bats`

## Verification

bats tests/unit/lib_costs.bats

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

### 2026-04-03T20:00:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-807-unit-tests-for-libcostssh-token-tracking.md
- **Context:** Initial task creation

### 2026-04-12T07:55:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f93b3846
- **Timestamp:** 2026-06-02T15:04:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
