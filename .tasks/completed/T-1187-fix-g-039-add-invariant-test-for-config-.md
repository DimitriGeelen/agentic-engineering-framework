---
id: T-1187
name: "Fix G-039: add invariant test for config registry parity across lib/config.sh,
  web/blueprints/config.py, CLAUDE.md"
description: >
  Fix G-039: add invariant test for config registry parity across lib/config.sh, web/blueprints/config.py,
  CLAUDE.md

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T21:25:43Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-12T21:27:48Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1187: Fix G-039: add invariant test for config registry parity across lib/config.sh, web/blueprints/config.py, CLAUDE.md

## Context

G-039: Config registry is enumerated in 3 places (`lib/config.sh`, `web/blueprints/config.py`, `CLAUDE.md`). All 3 currently match but have no structural link. Fix: add invariant test that extracts keys from all 3 sources and verifies parity.

## Acceptance Criteria

### Agent
- [x] Invariant test `tests/lint/config-registry-parity.bats` verifies all 3 sources have the same config keys
- [x] Test passes with current state (all 3 sources are in sync, 18 keys, 3/3 tests pass)
- [x] G-039 marked resolved in concerns.yaml

## Verification

bats tests/lint/config-registry-parity.bats

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

### 2026-04-12T21:25:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1187-fix-g-039-add-invariant-test-for-config-.md
- **Context:** Initial task creation

### 2026-04-12T21:27:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ac4b165f
- **Timestamp:** 2026-06-02T14:55:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
