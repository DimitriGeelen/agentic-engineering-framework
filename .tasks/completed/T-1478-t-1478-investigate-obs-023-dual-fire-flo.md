---
id: T-1478
name: "T-1478: investigate OBS-023 dual-fire flock guard ineffective + LATEST.md append
  bug"
description: >
  T-1478: investigate OBS-023 dual-fire flock guard ineffective + LATEST.md append
  bug

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-25T21:19:53Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T21:25:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1478: T-1478: investigate OBS-023 dual-fire flock guard ineffective + LATEST.md append bug

## Context

OBS-023: every `/compact` produces TWO pre-compact runs (compact-log shows two entries at the same second). T-1476's flock guard landed but did NOT stop it — empirical test (this session) shows two log entries at 21:10:30Z after the flock fix.

**Root cause (T-1478 finding):** The hooks fire close enough in time to look concurrent, but the `trap "rm -f LOCK_FILE" EXIT` in T-1476's flock block makes the flock ineffective for sequential dual-fires:
1. Run A: `exec 201>file`, `flock -n 201` → success, runs handover
2. Run A: exits → trap removes lockfile
3. Run B: `exec 201>file` → opens NEW inode at same path
4. Run B: `flock -n 201` → success (new inode has no holder)
5. Both runs produce handover content; handover.sh uses `cat > FILE` then many `>>` appends, so concurrent or near-concurrent writes interleave → duplicate sections in LATEST.md.

**Fix:** Layer time-window dedup on top of flock. Drop the trap-rm. The lockfile becomes a permanent empty marker (~0 bytes), and a sibling `.pre-compact.last-run` stores the last-run epoch. Second invocation within `PRE_COMPACT_DEDUP_WINDOW` (30s) exits silently.

## Acceptance Criteria

### Agent
- [x] `pre-compact.sh` no longer rms the lock file on EXIT (trap removed or scoped)
- [x] `pre-compact.sh` writes/reads `.pre-compact.last-run` and exits 0 when last run was <30s ago
- [x] `bash -n agents/context/pre-compact.sh` passes
- [x] bats test `tests/unit/pre_compact_timewindow_dedup.bats` passes (9/9)
- [x] Existing `tests/unit/pre_compact_flock.bats` passes (7/7, trap-existence flipped to trap-absence)
- [x] Sequential dual-fire reproduction: invoking pre-compact.sh twice in a row produces only ONE compact-log entry (verified — delta=1)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Source-level invariants
grep -q 'PRE_COMPACT_DEDUP_FILE=' agents/context/pre-compact.sh
grep -q 'PRE_COMPACT_DEDUP_WINDOW=' agents/context/pre-compact.sh
# Trap-rm of lockfile is gone (the bug from T-1476)
! grep -qE "^[[:space:]]*trap[[:space:]].*rm[[:space:]].*PRE_COMPACT_LOCK_FILE.*EXIT" agents/context/pre-compact.sh
# Parses
bash -n agents/context/pre-compact.sh
# Tests
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/pre_compact_timewindow_dedup.bats
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/pre_compact_flock.bats

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

### 2026-04-25T21:19:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1478-t-1478-investigate-obs-023-dual-fire-flo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b98dcb99
- **Timestamp:** 2026-06-02T14:57:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T21:25:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
