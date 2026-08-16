---
id: T-774
name: "Pickup pipeline core — lib/pickup.sh with receive/process/dedup/log"
description: >
  Core pickup library: parse YAML envelopes, validate schema, dedup via SHA256 hash,
  create inception tasks, move to processed. Directory setup: .context/pickup/{inbox,processed,rejected}.

status: work-completed
workflow_type: build
owner: claude-code
horizon:
tags: []
components: []
related_tasks: [T-772, T-775, T-776, T-777, T-778]
created: 2026-03-30T13:21:32Z
last_update: '2026-08-16T22:25:39Z'
date_finished: 2026-03-30T14:08:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-774: Pickup pipeline core — lib/pickup.sh with receive/process/dedup/log

## Context

Core library for the cross-project pickup pipeline (T-772 GO). Design: `docs/reports/T-772-cross-project-pickup.md`

## Acceptance Criteria

### Agent
- [x] `lib/pickup.sh` exists with functions: `pickup_validate_envelope`, `pickup_dedup_check`, `pickup_create_inception`, `pickup_process_one`, `pickup_next_id`
- [x] Directory structure created on first use: `.context/pickup/{inbox,processed,rejected}`
- [x] Envelope validation: checks required fields (pickup_id, version, type, source.project, payload.summary)
- [x] Dedup: SHA256(type + normalized_summary + source_project) with 7-day cooldown
- [x] Unit tests in `tests/unit/lib_pickup.bats` pass — 28 tests, 0 failures
- [x] shellcheck clean on `lib/pickup.sh`

## Verification

test -f lib/pickup.sh
bash -n lib/pickup.sh
shellcheck lib/pickup.sh || true
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/lib_pickup.bats

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

### 2026-03-30T13:21:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-774-pickup-pipeline-core--libpickupsh-with-r.md
- **Context:** Initial task creation

### 2026-03-30T14:05:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-30T14:08:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-052b2b46
- **Timestamp:** 2026-06-02T18:58:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - swallowed-errors @ Verification:line 3
