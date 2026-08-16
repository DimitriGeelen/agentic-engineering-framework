---
id: T-736
name: "Fix component detail source path — use ACTUAL_PROJECT_ROOT"
description: >
  Fix component detail source path — use ACTUAL_PROJECT_ROOT

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-29T20:56:04Z
last_update: '2026-08-16T22:25:38Z'
date_finished: 2026-03-29T21:00:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-736: Fix component detail source path — use ACTUAL_PROJECT_ROOT

## Context

`component_detail()` in fabric.py uses `PROJECT_ROOT` for source file resolution. In consumer projects, `PROJECT_ROOT` is `.agentic-framework/` but source files live at the actual project root. Should use `ACTUAL_PROJECT_ROOT` (introduced in T-730).

## Acceptance Criteria

### Agent
- [x] `component_detail()` uses `ACTUAL_PROJECT_ROOT` for source path resolution
- [x] Path traversal check uses `ACTUAL_PROJECT_ROOT`
- [x] Vendor copy synced
- [x] Component detail page still shows source code

## Verification

python3 -c "import ast; ast.parse(open('web/blueprints/fabric.py').read())"
grep -q "ACTUAL_PROJECT_ROOT" web/blueprints/fabric.py
grep -qm1 "Component:" <(curl -s http://localhost:3000/fabric/component/fw)

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

### 2026-03-29T20:56:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-736-fix-component-detail-source-path--use-ac.md
- **Context:** Initial task creation

### 2026-03-29T21:00:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0359a89a
- **Timestamp:** 2026-06-02T15:04:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
