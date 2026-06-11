---
id: T-1564
name: "L-302 sweep: 49 sites across 13 agents/ scripts (handover, audit, context,
  fabric)"
description: >
  L-302 sweep: 49 sites across 13 agents/ scripts (handover, audit, context, fabric)

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-27T20:45:54Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-27T20:48:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1564: L-302 sweep: 49 sites across 13 agents/ scripts (handover, audit, context, fabric)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] 49 grep|head sites across 13 agents/ scripts wrapped with `{ grep ... 2>/dev/null || true; }` — same recipe as T-1562 / T-1563 / T-1560. Files touched: handover.sh (7), audit.sh (8), git/lib/{hooks,status}.sh (3), context/{check-active-task,post-compact-resume,lib/focus}.sh (15), task-create/update-task.sh (1 stragglers), resume.sh (1), fabric/lib/{drift,traverse,query,summary}.sh (14).
- [x] Smoke test: `bin/fw doctor` + `bin/fw audit --section structure` both succeed end-to-end (no silent pipefail death from sweep).
- [x] Targeted bats green: skip_ac_partial_complete, create_task, yaml_pipefail (29), context_focus + check_active_task_memory_exempt (8+), handover_push_no_origin (8), fabric (10).

### Human
<!-- All ACs are agent-verifiable. -->

## Verification

# Smoke checks: doctor + audit run end-to-end (rc≤1 = warnings ok, rc=2 = failures)
bin/fw doctor >/dev/null
bin/fw audit --section structure >/dev/null 2>&1; rc=$?; [ $rc -le 1 ]

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

### 2026-04-27T20:45:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1564-l-302-sweep-49-sites-across-13-agents-sc.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c7ac5037
- **Timestamp:** 2026-06-02T14:58:20Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — 49 grep|head sites across 13 agents/ scripts wrapped with `{ grep ... 2>/dev/null || true; }` — same recipe as T-1562 / T-1563 / T-1560. Files touched: handover.sh (7), audit.sh (8), git/lib/{hooks,st
  - **AC-verify-mismatch** (narrow, heuristic) — `path=task-create/update-task.sh in: 49 grep|head sites across 13 agents/ scripts wrapped with `{ grep ... 2>/dev/null || true; }` — same recipe as T-1562 / T-1563 / T-1560. Files touched`

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw doctor >/dev/null`
### 2026-04-27T20:48:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
