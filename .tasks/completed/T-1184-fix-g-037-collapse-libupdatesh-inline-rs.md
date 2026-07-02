---
id: T-1184
name: "Fix G-037: collapse lib/update.sh inline rsync into do_vendor call — eliminate
  second includes enumeration"
description: >
  Fix G-037: collapse lib/update.sh inline rsync into do_vendor call — eliminate second
  includes enumeration

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T21:13:08Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-12T21:15:52Z
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

# T-1184: Fix G-037: collapse lib/update.sh inline rsync into do_vendor call — eliminate second includes enumeration

## Context

G-037: `lib/update.sh:_do_update_vendored()` maintains its own `includes=()` and `excludes=()` arrays parallel to `do_vendor()` in `bin/fw`. Same enumeration-divergence class as G-024. Fix: replace inline rsync loop with `do_vendor --source ... --target ...`.

## Acceptance Criteria

### Agent
- [x] `lib/update.sh` no longer has its own `includes=()` array for vendor files
- [x] `lib/update.sh` calls `do_vendor --source ... --target ...` for vendored file sync
- [x] Invariant test passes: `tests/lint/single-vendor-writer.bats` (6/6 pass)
- [x] G-037 marked resolved in concerns.yaml

## Verification

! grep -q 'local includes=(' lib/update.sh
grep -q 'do_vendor' lib/update.sh
bats tests/lint/single-vendor-writer.bats

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

### 2026-04-12T21:13:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1184-fix-g-037-collapse-libupdatesh-inline-rs.md
- **Context:** Initial task creation

### 2026-04-12T21:15:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-463f88f0
- **Timestamp:** 2026-06-02T14:55:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
