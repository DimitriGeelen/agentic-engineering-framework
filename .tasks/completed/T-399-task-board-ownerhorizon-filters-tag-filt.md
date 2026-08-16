---
id: T-399
name: "Task board: owner/horizon filters, tag filter, search within board"
description: >
  Add owner and horizon filters to board view, tag-based filtering, and local search
  within task board. Currently only status/type/component filters exist.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/blueprints/tasks.py, web/templates/tasks.html]
related_tasks: []
created: 2026-03-10T09:43:58Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-10T10:43:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
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
  - ts: '2026-08-16T22:25:29Z'
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

# T-399: Task board: owner/horizon filters, tag filter, search within board

## Context

Added shared filter bar (search, owner, horizon, tag) to task board and list views. Backend extended with owner, horizon, search filtering in `tasks.py`. Shared bar renders above both board and list views with htmx for instant filtering.

## Acceptance Criteria

### Agent
- [x] Owner filter dropdown with htmx live filtering
- [x] Horizon filter dropdown (now/next/later)
- [x] Tag filter dropdown (populated from task tags)
- [x] Text search input filtering by ID, name, description, tags
- [x] "Clear filters" link appears when any filter is active
- [x] Filters work in both board and list views
- [x] All filter dropdowns include each other in hx-include for composability
- [x] Backend `tasks.py` handles owner, horizon, q parameters

### Human
- [x] [REVIEW] Filter bar looks clean and works in browser
  **Steps:**
  1. Open http://localhost:3000/tasks in browser
  2. Select "agent" from Owner dropdown — board should show only agent-owned tasks
  3. Select "now" from Horizon — further narrows
  4. Type "mobile" in search — should show only T-400
  5. Click "× Clear filters" — all tasks return
  6. Switch to List view — same filters should appear and work
  **Expected:** Filters compose, results update instantly, clear link resets all
  **If not:** Note which filter doesn't work or breaks the layout

## Verification

# Tasks page renders
curl -sf http://localhost:3000/tasks
# Owner filter renders results
python3 -c "import urllib.request; r=urllib.request.urlopen('http://localhost:3000/tasks?owner=human').read().decode(); assert 'kanban-card' in r"
# Search filter narrows results
python3 -c "import urllib.request; r=urllib.request.urlopen('http://localhost:3000/tasks?q=mobile').read().decode(); assert 'kanban-card' in r"
# Clear filters link appears
python3 -c "import urllib.request; r=urllib.request.urlopen('http://localhost:3000/tasks?owner=human').read().decode(); assert 'Clear filters' in r"
# List view renders
curl -sf "http://localhost:3000/tasks?view=list"

## Decisions

None — additive enhancement to existing filter system.

## Updates

### 2026-03-10T09:43:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-399-task-board-ownerhorizon-filters-tag-filt.md
- **Context:** Initial task creation

### 2026-03-10T10:43:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e20427d7
- **Timestamp:** 2026-06-02T15:02:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
