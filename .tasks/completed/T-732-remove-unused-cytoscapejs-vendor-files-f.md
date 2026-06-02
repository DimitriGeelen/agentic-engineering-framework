---
id: T-732
name: "Remove unused Cytoscape.js vendor files from base.html"
description: >
  Remove unused Cytoscape.js vendor files from base.html

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T20:45:23Z
last_update: 2026-03-29T20:47:18Z
date_finished: 2026-03-29T20:47:18Z
---

# T-732: Remove unused Cytoscape.js vendor files from base.html

## Context

T-730/T-731 replaced Cytoscape graph with D3. Cytoscape.min.js and cytoscape-dagre.js are still loaded globally in base.html but no template uses them. ~500KB of dead JS on every page load.

## Acceptance Criteria

### Agent
- [x] Cytoscape script tags removed from base.html
- [x] cytoscape.min.js and cytoscape-dagre.js deleted from web/static/
- [x] Cytoscape fabric component cards removed (none existed)
- [x] Vendor copies synced

## Verification

test ! -f web/static/cytoscape.min.js
test ! -f web/static/cytoscape-dagre.js
! grep -q "cytoscape" web/templates/base.html
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

### 2026-03-29T20:45:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-732-remove-unused-cytoscapejs-vendor-files-f.md
- **Context:** Initial task creation

### 2026-03-29T20:47:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d4a33f7e
- **Timestamp:** 2026-06-02T15:04:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
