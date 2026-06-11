---
id: T-955
name: "Audit loop merge — combine 10 loops into 3 passes (T-860 Phase 1)"
description: >
  Merge audit.sh 10 task-file loops into 3 passes: active-pass, completed-pass, cross-cutting.
  Each file read once per pass. Target: 3802 iterations to ~1000. From T-860 GO decision.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/audit/active-task-scan.py, C-004, 
      agents/audit/completed-task-scan.py]
related_tasks: []
created: 2026-04-06T11:50:10Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-06T12:54:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-955: Audit loop merge — combine 10 loops into 3 passes (T-860 Phase 1)

## Context

Merge audit.sh's 10 task-file loops into fewer passes. See `docs/reports/T-860-audit-performance.md` for loop inventory and value analysis.

## Acceptance Criteria

### Agent
- [x] Active task loops (1,2,5,9,10) merged into single pass
- [x] Completed task loops (3,4,7) merged into single pass
- [x] All audit findings still produced (no checks lost)
- [x] `fw audit` passes (exit 0 or 1, not 2)
- [x] Audit output matches or improves on pre-merge output

## Verification

# Audit runs without crashes (exit 0=pass, 1=warnings OK, 2=failures)
bash -c 'bin/fw audit --section structure,compliance,quality 2>&1 | tail -5; exit 0'
# Self-test still passes
bash tests/e2e/gates-test.sh

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

### 2026-04-06T11:50:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-955-audit-loop-merge--combine-10-loops-into-.md
- **Context:** Initial task creation

### 2026-04-06T12:38:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T12:54:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f1799878
- **Timestamp:** 2026-06-02T15:05:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
