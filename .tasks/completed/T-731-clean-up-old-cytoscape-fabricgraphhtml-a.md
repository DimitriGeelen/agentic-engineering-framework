---
id: T-731
name: "Clean up old Cytoscape fabric_graph.html after D3 explorer integration"
description: >
  Clean up old Cytoscape fabric_graph.html after D3 explorer integration

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-29T20:43:09Z
last_update: '2026-06-11T22:24:28Z'
date_finished: 2026-03-29T20:45:01Z
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-731: Clean up old Cytoscape fabric_graph.html after D3 explorer integration

## Context

T-730 replaced Cytoscape graph with D3 Fabric Explorer. Old `fabric_graph.html` template and its component card are dead code. Fabric blueprint component card still references old template.

## Acceptance Criteria

### Agent
- [x] `web/templates/fabric_graph.html` deleted
- [x] `.fabric/components/web-templates-fabric_graph.yaml` deleted
- [x] `.fabric/components/web-blueprints-fabric.yaml` updated to reference `fabric_explorer.html`
- [x] Vendor copies synced
- [x] Watchtower still works after cleanup

## Verification

test ! -f web/templates/fabric_graph.html
test ! -f .fabric/components/web-templates-fabric_graph.yaml
grep -q "fabric_explorer.html" .fabric/components/web-blueprints-fabric.yaml
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

### 2026-03-29T20:43:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-731-clean-up-old-cytoscape-fabricgraphhtml-a.md
- **Context:** Initial task creation

### 2026-03-29T20:45:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0b53fbbc
- **Timestamp:** 2026-06-02T15:04:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
