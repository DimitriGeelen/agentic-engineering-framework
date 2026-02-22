---
id: T-233
name: "Improve fabric graph layout"
description: >
  Improve fabric graph layout

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/blueprints/fabric.py, web/templates/fabric_graph.html]
related_tasks: []
created: 2026-02-21T20:01:36Z
last_update: 2026-02-22T08:46:17Z
date_finished: 2026-02-21T20:14:28Z
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
