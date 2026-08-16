---
id: T-730
name: "Integrate D3.js Fabric Explorer into upstream Watchtower"
description: >
  Integrate D3.js Fabric Explorer into upstream Watchtower

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-29T20:13:54Z
last_update: '2026-08-16T22:25:38Z'
date_finished: 2026-03-29T20:36:29Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-730: Integrate D3.js Fabric Explorer into upstream Watchtower

## Context

Integrate D3.js Fabric Explorer from OpenClaw evaluation into upstream Watchtower. Inception T-726 approved GO. Source files at `/opt/openclaw-evaluation/.agentic-framework/web/`. See `docs/reports/T-726-fabric-explorer-integration.md` for full diff analysis.

## Acceptance Criteria

### Agent
- [x] fabric_explorer.html copied and adapted for framework paths
- [x] fabric.py merged — new graph route + 2 API routes + enhanced _load_subsystems
- [x] d3.v7.min.js vendored to web/static/
- [x] Existing routes still work: /fabric, /fabric/component/<name>
- [x] New routes work: /fabric/graph (explorer), /api/fabric/report, /api/fabric/source
- [x] Path traversal protection verified on source API
- [x] Vendor copies synced to .agentic-framework/

### Human
- [x] [REVIEW] Fabric Explorer renders correctly with interactive graph
  **Steps:**
  1. Open http://192.168.10.107:3000/fabric/graph in browser
  2. Verify force-directed graph loads with subsystem bubbles
  3. Click a subsystem node — verify detail pane opens
  4. Click + to expand inline components
  5. Try the search box
  **Expected:** Interactive graph with clickable nodes, expandable subsystems, detail panes
  **If not:** Note which feature is broken and browser console errors

## Verification

grep -qm1 "Component Fabric" <(curl -s http://localhost:3000/fabric)
grep -qm1 "Fabric Explorer" <(curl -s http://localhost:3000/fabric/graph)
grep -qm1 "componentData" <(curl -s http://localhost:3000/fabric/graph)
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

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 7 agent ACs verified, 4/4 verification commands pass. D3 explorer replaces Cytoscape graph with interactive force-directed visualization. Path traversal protection verified. All existing routes preserved.
- **Evidence:**
  - `/fabric` returns "Component Fabric" (200 OK)
  - `/fabric/graph` returns "Fabric Explorer" with componentData (200 OK)
  - `/fabric/component/<name>` still works (200 OK)
  - `/api/fabric/source/../../etc/passwd` returns 404 (path traversal blocked)
  - `/api/fabric/source/bin/fw` returns file content (200 OK)
  - `/api/fabric/report/T-726-fabric-explorer-integration.md` returns report (200 OK)
  - Vendor copies synced to `.agentic-framework/`

## Updates

### 2026-03-29T20:13:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-730-integrate-d3js-fabric-explorer-into-upst.md
- **Context:** Initial task creation

### 2026-03-29T20:36:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f4c6e9d4
- **Timestamp:** 2026-06-02T15:04:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
