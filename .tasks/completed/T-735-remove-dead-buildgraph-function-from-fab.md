---
id: T-735
name: "Remove dead _build_graph function from fabric.py"
description: >
  Remove dead _build_graph function from fabric.py

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T20:53:20Z
last_update: 2026-03-29T20:54:45Z
date_finished: 2026-03-29T20:54:45Z
---

# T-735: Remove dead _build_graph function from fabric.py

## Context

`_build_graph()` was used by the old Cytoscape `/fabric/graph` route. The D3 Fabric Explorer (T-730) builds graphs client-side. Function is dead code (82 lines).

## Acceptance Criteria

### Agent
- [x] `_build_graph` function removed from fabric.py
- [x] fabric.py still passes syntax check
- [x] Vendor copy synced
- [x] All fabric routes still work

## Verification

python3 -c "import ast; ast.parse(open('web/blueprints/fabric.py').read())"
! grep -q "_build_graph" web/blueprints/fabric.py
grep -qm1 "Fabric Explorer" <(curl -s http://localhost:3000/fabric/graph)

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

### 2026-03-29T20:53:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-735-remove-dead-buildgraph-function-from-fab.md
- **Context:** Initial task creation

### 2026-03-29T20:54:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-21868db6
- **Timestamp:** 2026-06-02T15:04:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
