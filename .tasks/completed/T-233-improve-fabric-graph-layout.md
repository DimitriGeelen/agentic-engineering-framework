---
id: T-233
name: "Improve fabric graph layout"
description: >
  Improve fabric graph layout

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/blueprints/fabric.py, web/templates/fabric_graph.html]
related_tasks: []
created: 2026-02-21T20:01:36Z
last_update: '2026-08-16T22:25:02Z'
date_finished: 2026-02-21T20:14:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:16Z'
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
  - ts: '2026-08-16T22:25:02Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-233: Improve fabric graph layout

## Context

95 nodes + 140 edges rendered with cose = cluttered hairball. Added dagre hierarchical layout, compound subsystem nodes, layout mode switcher, degree-based node sizing.

## Acceptance Criteria

### Agent
- [x] Dagre layout (top-down) as default with subsystem compound nodes
- [x] Layout mode switcher with 3 modes (dagre TB, dagre LR, force-directed)
- [x] Node size scales by degree (hubs larger, leaves smaller)
- [x] Viewport height uses calc(100vh - 220px) instead of fixed 600px
- [x] Info panel shows connection count (in/out degree)

### Human
- [x] Hierarchy layout clearly shows fw at top with subsystem groupings
- [x] Force-directed view reveals natural clustering
- [x] Labels readable at default zoom

## Verification

# Graph page loads
curl -sf http://localhost:3000/fabric/graph | grep -q "dagre"
# Dagre and cytoscape-dagre libraries exist
test -f web/static/dagre.min.js && test -f web/static/cytoscape-dagre.js
# Template has all 3 layout modes
grep -q "top-down" web/templates/fabric_graph.html && grep -q "left-right" web/templates/fabric_graph.html && grep -q "Force-directed" web/templates/fabric_graph.html

## Decisions

### 2026-02-21 — Layout approach for clustered mode
- **Chose:** dagre LR (left-to-right) for second layout mode
- **Why:** cose with compound parent nodes creates extremely elongated layouts (3.5:1 ratio) at 95-node scale
- **Rejected:** cose-compound — force-directed layout can't handle 12 subsystem compound parents well; produces unusable vertical strips

## Updates

### 2026-02-21T20:01:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-233-improve-fabric-graph-layout.md
- **Context:** Initial task creation

### 2026-02-21T20:14:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ce3caea8
- **Timestamp:** 2026-06-02T15:01:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/fabric/graph | grep -q "dagre"`
