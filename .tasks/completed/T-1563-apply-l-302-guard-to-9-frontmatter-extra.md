---
id: T-1563
name: "Apply L-302 guard to 9 frontmatter-extraction sites in update-task.sh"
description: >
  Apply L-302 guard to 9 frontmatter-extraction sites in update-task.sh

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-27T20:36:07Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-27T20:37:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1563: Apply L-302 guard to 9 frontmatter-extraction sites in update-task.sh

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] All 12 inline `grep "^FIELD:" "$TASK_FILE" | head -1 | sed ...` sites in `agents/task-create/update-task.sh` wrapped with `{ grep ... 2>/dev/null || true; }` — same recipe as T-1562 / T-1560 / T-1557. (9 unguarded + 3 with trailing `|| true` now defensively double-guarded.)
- [x] Existing update-task tests + skip_ac_partial_complete.bats (T-1559) green with the guarded code (29/29 tests across 3 bats files).

### Human
<!-- All ACs are agent-verifiable. -->

## Verification

bats tests/unit/skip_ac_partial_complete.bats tests/unit/create_task.bats tests/unit/yaml_pipefail.bats

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-04-27T20:36:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1563-apply-l-302-guard-to-9-frontmatter-extra.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ce5c6d2a
- **Timestamp:** 2026-06-02T14:58:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T20:37:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
