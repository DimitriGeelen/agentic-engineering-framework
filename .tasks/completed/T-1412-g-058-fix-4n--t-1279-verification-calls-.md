---
id: T-1412
name: "G-058 fix 4/N — T-1279 verification calls full audit (slow + 20s sweep timeout);
  replace with direct dup-ID check"
description: >
  G-058 fix 4/N — T-1279 verification calls full audit (slow + 20s sweep timeout);
  replace with direct dup-ID check

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-23T19:52:45Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T19:54:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1412: G-058 fix 4/N — T-1279 verification calls full audit (slow + 20s sweep timeout); replace with direct dup-ID check

## Context

T-1279's verification block included `bash -c "bin/fw audit 2>&1 > /tmp/...
grep ..."` to assert no duplicate task IDs exist. The full audit takes
20-30s (it scans 1300+ task files plus runs structure / fabric / yaml
checks). T-1404's verification sweep imposes a 20s per-check timeout
to keep the sweep tractable, so this verification times out — not because
duplicates exist, but because the audit is too coarse a tool for a
focused check.

G-058 finding 5/6.

Fix: replace the audit invocation with a direct duplicate-ID check on
filename prefixes (~16ms vs ~25s). Same semantic — assert
`uniq -d` on T-IDs across active/ + completed/ produces zero rows.

## Acceptance Criteria

### Agent
- [x] T-1279's audit-based dup check replaced with direct file-listing equivalent
- [x] New check runs in 16ms (vs full audit's ~25s)
- [x] Direct check passes against current state (no duplicates)
- [x] Other 2 verification commands in T-1279 unchanged (bats + keylock grep)

## Verification

bats tests/unit/task_id_race.bats
grep -q 'keylock_acquire.*task-id' agents/task-create/create-task.sh
test "$(ls .tasks/active/T-*.md .tasks/completed/T-*.md 2>/dev/null | grep -oE '/T-[0-9]+-' | sort | uniq -d | wc -l)" -eq 0

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

### 2026-04-23T19:52:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1412-g-058-fix-4n--t-1279-verification-calls-.md
- **Context:** Initial task creation

### 2026-04-23T19:54:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-62763bfd
- **Timestamp:** 2026-06-02T14:57:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
