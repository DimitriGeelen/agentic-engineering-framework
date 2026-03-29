---
id: T-730
name: "Integrate D3.js Fabric Explorer into upstream Watchtower"
description: >
  Integrate D3.js Fabric Explorer into upstream Watchtower

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-29T20:13:54Z
last_update: 2026-03-29T20:13:54Z
date_finished: null
---

# T-730: Integrate D3.js Fabric Explorer into upstream Watchtower

## Context

Integrate D3.js Fabric Explorer from OpenClaw evaluation into upstream Watchtower. Inception T-726 approved GO. Source files at `/opt/openclaw-evaluation/.agentic-framework/web/`. See `docs/reports/T-726-fabric-explorer-integration.md` for full diff analysis.

## Acceptance Criteria

### Agent
- [ ] fabric_explorer.html copied and adapted for framework paths
- [ ] fabric.py merged — new graph route + 2 API routes + enhanced _load_subsystems
- [ ] d3.v7.min.js vendored to web/static/
- [ ] Existing routes still work: /fabric, /fabric/component/<name>
- [ ] New routes work: /fabric/graph (explorer), /api/fabric/report, /api/fabric/source
- [ ] Path traversal protection verified on source API
- [ ] Vendor copies synced to .agentic-framework/

### Human
- [ ] [REVIEW] Fabric Explorer renders correctly with interactive graph
  **Steps:**
  1. Open http://192.168.10.107:3000/fabric/graph in browser
  2. Verify force-directed graph loads with subsystem bubbles
  3. Click a subsystem node — verify detail pane opens
  4. Click + to expand inline components
  5. Try the search box
  **Expected:** Interactive graph with clickable nodes, expandable subsystems, detail panes
  **If not:** Note which feature is broken and browser console errors

## Verification

curl -sf http://localhost:3000/fabric | grep -q "Component Fabric"
curl -sf http://localhost:3000/fabric/graph | grep -q "Fabric Explorer"
curl -sf http://localhost:3000/fabric/graph | grep -q "componentData"
# Source API — path traversal blocked
test "$(curl -s -o /dev/null -w '%{http_code}' 'http://localhost:3000/api/fabric/source/../../etc/passwd')" = "403" -o "$(curl -s -o /dev/null -w '%{http_code}' 'http://localhost:3000/api/fabric/source/../../etc/passwd')" = "404"

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

### 2026-03-29T20:13:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-730-integrate-d3js-fabric-explorer-into-upst.md
- **Context:** Initial task creation
