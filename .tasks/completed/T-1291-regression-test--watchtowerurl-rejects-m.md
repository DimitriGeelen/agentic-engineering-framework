---
id: T-1291
name: "Regression test — _watchtower_url rejects masquerader (T-1284 B6)"
description: >
  Regression test — _watchtower_url rejects masquerader (T-1284 B6)

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-17T22:01:10Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-18T08:50:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
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

# T-1291: Regression test — _watchtower_url rejects masquerader (T-1284 B6)

## Context

B6 of T-1284. Locks the fix in: a bats test that simulates the
masquerade scenario (a sibling service answering on a probed port
with the wrong project_root). Without the T-1290 rewrite this
test would fail — with it, it passes.

Tests use a tiny Python HTTP server on a random high port to play
the masquerade role. No network dependencies outside localhost.

## Acceptance Criteria

### Agent
- [x] `tests/unit/lib_watchtower.bats` exists
- [x] Test: masquerader on configured port with wrong project_root →
      `_watchtower_url` exits non-zero
- [x] Test: `WATCHTOWER_URL` env override still returns verbatim
- [x] Test: no Watchtower at all → exits non-zero with stderr message
- [x] `bats tests/unit/lib_watchtower.bats` passes (5/5)

## Verification

bats tests/unit/lib_watchtower.bats

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

### 2026-04-17T22:01:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1291-regression-test--watchtowerurl-rejects-m.md
- **Context:** Initial task creation

### 2026-04-18T08:50:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-34902087
- **Timestamp:** 2026-06-02T14:56:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
