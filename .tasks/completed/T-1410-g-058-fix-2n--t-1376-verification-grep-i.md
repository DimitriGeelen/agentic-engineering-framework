---
id: T-1410
name: "G-058 fix 2/N — T-1376 verification grep is inverted (passes when bug present,
  blocks when bug fixed)"
description: >
  G-058 fix 2/N — T-1376 verification grep is inverted (passes when bug present, blocks
  when bug fixed)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-23T19:47:26Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T19:49:12Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1410: G-058 fix 2/N — T-1376 verification grep is inverted (passes when bug present, blocks when bug fixed)

## Context

T-1376's `## Verification` block contains 3 inverted greps:
```
grep -qn "localhost:3000" lib/init.sh
grep -qn "localhost:3000" lib/templates/claude-project.md
grep -qn "localhost:3000" agents/monitor/liveness-check.sh
```
Each exits 0 only if the file *contains* `localhost:3000` — i.e. only when
the bug T-1376 was created to remove is still present. The grep semantics
are inverted: the gate fires green for a *failed* fix and blocks for a
*successful* one. Since the underlying anti-pattern sites have been
cleaned (no file currently contains `localhost:3000`), the verification
block is now permanently failing.

G-058 finding 3/6.

Fix: prefix each line with `!` to negate, so the verification asserts
"this file does NOT contain localhost:3000" (the actual post-fix state).

## Acceptance Criteria

### Agent
- [x] All 3 greps in T-1376's verification block negated (`! grep -qn ...`)
- [x] Verification block reads as: "files MUST NOT contain `localhost:3000`"
- [x] Each verification line passes against current source (no `localhost:3000` hits)

## Verification

! grep -qn "localhost:3000" lib/init.sh
! grep -qn "localhost:3000" lib/templates/claude-project.md
! grep -qn "localhost:3000" agents/monitor/liveness-check.sh

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

### 2026-04-23T19:47:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1410-g-058-fix-2n--t-1376-verification-grep-i.md
- **Context:** Initial task creation

### 2026-04-23T19:49:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8d563e46
- **Timestamp:** 2026-06-02T14:57:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
