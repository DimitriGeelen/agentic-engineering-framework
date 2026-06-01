---
id: T-849
name: "Fix Fabric Explorer double-refresh bug — componentData hoisting + hardcoded OpenClaw data"
description: >
  Fabric Explorer at /fabric/graph requires two page refreshes to render. Root cause: componentData const referenced before initialization in JS execution order. Additionally, ~100 lines of hardcoded OpenClaw project data (layers, subsystems, edges) remain from the integration (T-730). Evidence: processed pickups P-001 and P-002 from 051-vinix24 OpenClaw evaluation.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-04T15:03:56Z
last_update: 2026-04-13T06:28:11Z
date_finished: 2026-04-04T21:59:51Z
---

# T-849: Fix Fabric Explorer double-refresh bug — componentData hoisting + hardcoded OpenClaw data

## Context

Fabric Explorer at /fabric/graph has hardcoded OpenClaw project data from T-730 integration.
Title says "OpenClaw Fabric Explorer", stats show OpenClaw counts (154 components, 29 subsystems, 81 extensions).
All JS data objects (layers, subsystemData, edges, subsystemReports) contain OpenClaw architecture.
The +/- expand buttons return 0 components because actual fabric subsystem IDs don't match hardcoded OpenClaw IDs.
Evidence: processed pickups P-001 (hardcoded data) and P-002 (double-refresh) from 051-vinix24 evaluation.

## Acceptance Criteria

### Agent
- [x] No hardcoded OpenClaw data in fabric_explorer.html (no "OpenClaw" string, no hardcoded subsystemData/edges/layers/reports)
- [x] Header title shows "Fabric Explorer" (not "OpenClaw Fabric Explorer")
- [x] Stats subtitle shows actual component/subsystem counts from fabric data
- [x] subsystemData, edges, layers, subsystemReports generated dynamically in fabric.py from component cards
- [x] /fabric/graph returns HTTP 200

### Human
- [x] [REVIEW] Fabric Explorer renders on first page load without needing refresh
  **Steps:**
  1. Open http://localhost:3000/fabric/graph in a new browser tab
  2. Check that subsystem nodes appear with correct names and counts
  3. Click the + button on a subsystem node to expand inline components
  **Expected:** Graph renders immediately, subsystem names match actual project (Watchtower, Framework Core, etc.), + expand shows real components
  **If not:** Note which subsystem is broken and whether the graph is empty or shows wrong data

## Verification

curl -sf http://localhost:3000/fabric/graph -o /tmp/T-849-verify.html && grep -q "Fabric Explorer" /tmp/T-849-verify.html
python3 -c "import sys; html=open('web/templates/fabric_explorer.html').read(); sys.exit(1 if 'OpenClaw' in html else 0)"

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

### 2026-04-04T15:03:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-849-fix-fabric-explorer-double-refresh-bug--.md
- **Context:** Initial task creation

### 2026-04-04T21:59:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:27:23Z — status-update [task-update-agent]
- **Change:** horizon: now → next
