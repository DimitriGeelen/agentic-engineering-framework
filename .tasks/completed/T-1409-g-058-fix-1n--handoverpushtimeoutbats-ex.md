---
id: T-1409
name: "G-058 fix 1/N — handover_push_timeout.bats expects stale default 15s, T-1341
  bumped to 60s"
description: >
  G-058 fix 1/N — handover_push_timeout.bats expects stale default 15s, T-1341 bumped
  to 60s

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/handover_push_timeout.bats]
related_tasks: []
created: 2026-04-23T19:45:11Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T19:46:48Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1409: G-058 fix 1/N — handover_push_timeout.bats expects stale default 15s, T-1341 bumped to 60s

## Context

T-1341 bumped `FW_HANDOVER_PUSH_TIMEOUT` default from 15s → 60s in
`agents/handover/handover.sh:762` (`_push_timeout="${FW_HANDOVER_PUSH_TIMEOUT:-60}"`)
to accommodate pre-push audit. The accompanying test in
`tests/unit/handover_push_timeout.bats:69` was not updated and still greps
for the literal `${FW_HANDOVER_PUSH_TIMEOUT:-15}`. Result: 1 stale failing
test (`bats:7`), surfaced by T-1404's verification sweep as G-058 finding 1/6.

This is a pure test-fix: production code is correct.

## Acceptance Criteria

### Agent
- [x] tests/unit/handover_push_timeout.bats:69 updated to expect `:-60`
- [x] Test name updated from "default push timeout is 15s" → "default push timeout is 60s"
- [x] `bats tests/unit/handover_push_timeout.bats` passes 8/8 (was 7/8)

## Verification

bats tests/unit/handover_push_timeout.bats

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

### 2026-04-23T19:45:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1409-g-058-fix-1n--handoverpushtimeoutbats-ex.md
- **Context:** Initial task creation

### 2026-04-23T19:46:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8bb14d3f
- **Timestamp:** 2026-06-02T14:57:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
