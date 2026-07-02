---
id: T-1188
name: "Fix G-041 (partial): replace remaining hardcoded status lists in web Python
  with _load_enums()"
description: >
  Fix G-041 (partial): replace remaining hardcoded status lists in web Python with
  _load_enums()

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T21:32:34Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-12T21:37:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
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

# T-1188: Fix G-041 (partial): replace remaining hardcoded status lists in web Python with _load_enums()

## Context

G-041 partial: Replace remaining hardcoded status lists in `tasks.py:579`, `prioritizer.py:16-18`, and `core.py:190` with `_load_enums()` calls. The kanban template (19 references) is deferred — needs separate inception for template-level refactor.

## Acceptance Criteria

### Agent
- [x] `tasks.py:update_task_status` uses `_load_enums()["statuses"]` instead of hardcoded list
- [x] `prioritizer.py` uses domain-specific priority dict (not full enumeration — `.get(status, 2)` handles unknown statuses safely)
- [x] `core.py:190` uses domain-specific subset check (staleness applies only to started-work/captured — not a full enumeration)
- [x] No hardcoded full status lists remain in Python files (except fallback in `_load_enums` itself)
- [x] Python syntax valid (ast.parse passes)

## Verification

python3 -c "import ast; ast.parse(open('web/blueprints/tasks.py').read())"
python3 -c "import ast; ast.parse(open('web/watchtower/prioritizer.py').read())"
python3 -c "import ast; ast.parse(open('web/blueprints/core.py').read())"

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

### 2026-04-12T21:32:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1188-fix-g-041-partial-replace-remaining-hard.md
- **Context:** Initial task creation

### 2026-04-12T21:37:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-39f696be
- **Timestamp:** 2026-06-02T14:55:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
