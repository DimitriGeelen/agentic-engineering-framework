---
id: T-215
name: "Component Fabric — Watchtower UI page (visual browser + graph)"
description: >
  Add /fabric page to Watchtower web UI. Features: subsystem overview tiles, component
  list (filterable/searchable), component detail with clickable deps, visual dependency
  graph (D3/Cytoscape/SVG), impact highlighting, drift dashboard. Same stack as existing
  Watchtower. Human requested visual drill-down interface. Related: T-191.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [component-fabric, web, watchtower, visualization]
related_tasks: []
created: 2026-02-20T07:14:11Z
last_update: '2026-08-16T22:24:55Z'
date_finished: 2026-02-20T07:58:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-215: Component Fabric — Watchtower UI page (visual browser + graph)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] /fabric page loads with subsystem tiles and searchable/filterable component list
- [x] /fabric/component/<name> detail page shows deps, reverse deps, tags, metadata
- [x] /fabric/graph page renders Cytoscape.js dependency graph with typed node/edge coloring
- [x] Graph supports click-to-highlight downstream, info panel, re-layout, label toggle
- [x] Blueprint registered in app.py, "Architecture" nav group in shared.py
- [x] Subsystem filter on graph page navigates via htmx

### Human
- [x] Graph layout is readable and visually clear
- [x] Component detail page has sufficient information density
- [x] Navigation between fabric pages feels natural

## Verification

curl -sf http://localhost:3000/fabric
curl -sf http://localhost:3000/fabric/component/add-learning
curl -sf http://localhost:3000/fabric/graph
python3 -c "from web.blueprints.fabric import _load_components, _build_graph; cs=_load_components(); ns,es=_build_graph([c for c in cs if c.get('depends_on') or c.get('writers') or c.get('readers')]); assert len(ns)>0 and len(es)>0, f'graph empty: {len(ns)} nodes, {len(es)} edges'"

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

### 2026-02-20T07:14:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-215-component-fabric--watchtower-ui-page-vis.md
- **Context:** Initial task creation

### 2026-02-20T07:23:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-20T07:58:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-02-20T09:07:50Z — status-update [task-update-agent]
- **Change:** owner: human → human

## Reviewer Verdict (v1.5)

- **Scan ID:** R-33c02b1b
- **Timestamp:** 2026-06-02T15:01:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
