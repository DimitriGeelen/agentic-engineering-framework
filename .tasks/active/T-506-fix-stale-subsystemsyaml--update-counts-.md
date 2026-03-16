---
id: T-506
name: "Fix stale subsystems.yaml — update counts, add missing watchtower-web-ui"
description: >
  Fix stale subsystems.yaml — update counts, add missing watchtower-web-ui

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-16T06:23:53Z
last_update: 2026-03-16T06:23:53Z
date_finished: null
---

# T-506: Fix stale subsystems.yaml — update counts, add missing watchtower-web-ui

## Context

Subsystems.yaml had stale component_count values (created T-214, never updated since). Missing watchtower-web-ui subsystem. RCA: static snapshot with no update mechanism. Fix: derive counts dynamically from component cards.

## Acceptance Criteria

### Agent
- [x] subsystems.yaml counts updated to match reality
- [x] Missing watchtower-web-ui subsystem added to registry
- [x] Web UI derives subsystem counts dynamically (auto-discovers missing subsystems)
- [x] CLI `fw fabric overview` derives counts dynamically from cards
- [x] Both show 13 subsystems, 154 components

### Human
- [ ] [RUBBER-STAMP] Verify fabric page shows all subsystem tiles
  **Steps:**
  1. Open http://localhost:3000/fabric
  2. Count subsystem tiles in the grid
  **Expected:** 13 tiles, all with correct component counts
  **If not:** Check web/blueprints/fabric.py auto-discovery logic

## Verification

python3 -c "import yaml; yaml.safe_load(open('.fabric/subsystems.yaml'))"
curl -sf http://localhost:3000/fabric | python3 -c "import sys,re; html=sys.stdin.read(); tiles=re.findall(r'subsystem=', html); assert len(tiles)>=13, f'Only {len(tiles)} tiles'"

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

### 2026-03-16T06:23:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-506-fix-stale-subsystemsyaml--update-counts-.md
- **Context:** Initial task creation
