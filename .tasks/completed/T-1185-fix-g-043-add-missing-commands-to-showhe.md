---
id: T-1185
name: "Fix G-043: add missing commands to show_help + invariant test for router/help
  parity"
description: >
  Fix G-043: add missing commands to show_help + invariant test for router/help parity

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T21:17:49Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-12T21:19:30Z
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

# T-1185: Fix G-043: add missing commands to show_help + invariant test for router/help parity

## Context

G-043: 5 top-level commands (`ask`, `docs`, `enforcement`, `fabric`, `setup`) exist in the router case block but not in `show_help()`. Fix: add the 4 real commands to help (setup is already documented as deprecated alias). Add invariant test to prevent future drift.

## Acceptance Criteria

### Agent
- [x] `ask`, `docs`, `enforcement`, `fabric` commands appear in `show_help()`
- [x] Invariant test `tests/lint/help-router-parity.bats` catches any future drift (2/2 pass)
- [x] G-043 marked resolved in concerns.yaml

## Verification

bats tests/lint/help-router-parity.bats

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

### 2026-04-12T21:17:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1185-fix-g-043-add-missing-commands-to-showhe.md
- **Context:** Initial task creation

### 2026-04-12T21:19:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c4e6cd1c
- **Timestamp:** 2026-06-02T14:55:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
