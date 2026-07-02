---
id: T-1179
name: "Fix G-038: Replace hardcoded enums in tasks.py with status-transitions.yaml
  reads"
description: >
  Fix G-038: Replace hardcoded enums in tasks.py with status-transitions.yaml reads

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [web/blueprints/tasks.py, web/templates/tasks.html]
related_tasks: []
created: 2026-04-12T17:35:25Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-04-12T17:41:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
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

# T-1179: Fix G-038: Replace hardcoded enums in tasks.py with status-transitions.yaml reads

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] tasks.py reads workflow_types from status-transitions.yaml
- [x] tasks.py reads horizons from status-transitions.yaml
- [x] No hardcoded `allowed_types` or horizon lists in tasks.py
- [x] Web tests pass
- [x] Task creation form uses dynamic enums (Jinja loops)

## Verification

# No hardcoded allowed_types list in tasks.py
bash -c '! grep -q "allowed_types.*=.*\[" web/blueprints/tasks.py'
# Web tests pass
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/test_app.py::TestRoutes -x -q 2>&1 | tail -1 | grep -q "passed"

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

### 2026-04-12T17:35:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1179-fix-g-038-replace-hardcoded-enums-in-tas.md
- **Context:** Initial task creation

### 2026-04-12T17:41:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-441011af
- **Timestamp:** 2026-06-02T14:55:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/test_app.py::TestRoutes -x -q 2>&1 | tail -1 | grep -q "passed"`
