---
id: T-1386
name: "Bats regression test for G-056 resume.md drift-refresh — invariant protection
  for T-1383"
description: >
  Bats regression test for G-056 resume.md drift-refresh — invariant protection for
  T-1383

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-22T20:50:29Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-22T20:52:29Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1386: Bats regression test for G-056 resume.md drift-refresh — invariant protection for T-1383

## Context

Pins T-1383 behavior: `lib/upgrade.sh` must refresh consumer `.claude/commands/resume.md` when it drifts from `lib/templates/resume-md.md`, writing a `.bak`. Without this test G-056 could silently regress — closing it fully per G-019 ("don't close gaps until prevention exists"). Adds 3 cases to `tests/unit/lib_upgrade.bats`: stale drift triggers UPDATE, matching file reports OK, missing file CREATE from template.

## Acceptance Criteria

### Agent
- [x] 3 new bats tests in `tests/unit/lib_upgrade.bats` covering drift/match/missing
- [x] Tests pass: `fw test unit --filter lib_upgrade` or `bats tests/unit/lib_upgrade.bats` green
- [x] Sanity-inverse: temporarily revert T-1383 (use `git show 6ed3b503^:lib/upgrade.sh`), rerun tests — drift test MUST fail. Restore T-1383 version — tests pass again.

## Verification

bats tests/unit/lib_upgrade.bats >/tmp/t1386.out 2>&1 && grep -q 'detects resume.md drift' /tmp/t1386.out
bats tests/unit/lib_upgrade.bats >/tmp/t1386.out 2>&1 && grep -qE '0 failures|ok [0-9]+' /tmp/t1386.out

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

### 2026-04-22T20:50:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1386-bats-regression-test-for-g-056-resumemd-.md
- **Context:** Initial task creation

### 2026-04-22T20:52:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7b571079
- **Timestamp:** 2026-06-02T14:57:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
