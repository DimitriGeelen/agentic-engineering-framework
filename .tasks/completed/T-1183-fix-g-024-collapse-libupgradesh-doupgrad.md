---
id: T-1183
name: "Fix G-024: collapse lib/upgrade.sh do_upgrade step 4b into do_vendor call —
  sync all vendored files including web/"
description: >
  Fix G-024: collapse lib/upgrade.sh do_upgrade step 4b into do_vendor call — sync
  all vendored files including web/

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T21:10:29Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-12T21:12:07Z
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

# T-1183: Fix G-024: collapse lib/upgrade.sh do_upgrade step 4b into do_vendor call — sync all vendored files including web/

## Context

G-024 (HIGH): `fw upgrade` did not sync `web/blueprints/` to consumers, causing silent drift. T-1109 inception diagnosed the root cause (enumeration-divergence between `do_upgrade` and `do_vendor`). T-1157 already applied the fix: collapsed step 4b into a `do_vendor` call. This task verifies the fix, closes G-024, and confirms invariant tests guard against regression.

## Acceptance Criteria

### Agent
- [x] `lib/upgrade.sh` step 4b uses `do_vendor` (not inline per-file sync) — verified at lines 320-337
- [x] `do_vendor` includes `web` in its canonical list — verified at `bin/fw:185`
- [x] Invariant tests pass: `tests/lint/single-vendor-writer.bats` (4/4 pass)
- [x] G-024 marked resolved in concerns.yaml

## Verification

bats tests/lint/single-vendor-writer.bats
grep -q 'do_vendor --target' lib/upgrade.sh

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

### 2026-04-12T21:10:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1183-fix-g-024-collapse-libupgradesh-doupgrad.md
- **Context:** Initial task creation

### 2026-04-12T21:12:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c0e3d5df
- **Timestamp:** 2026-06-02T14:55:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
