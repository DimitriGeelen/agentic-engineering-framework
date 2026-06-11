---
id: T-506
name: "Fix stale subsystems.yaml — update counts, add missing watchtower-web-ui"
description: >
  Fix stale subsystems.yaml — update counts, add missing watchtower-web-ui

status: work-completed
workflow_type: refactor
owner: human
horizon:
tags: []
components: [agents/fabric/lib/summary.sh, web/blueprints/fabric.py]
related_tasks: []
created: 2026-03-16T06:23:53Z
last_update: '2026-06-11T22:24:23Z'
date_finished: 2026-03-16T06:30:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
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
- [x] [RUBBER-STAMP] Verify fabric page shows all subsystem tiles
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

### 2026-03-16T06:30:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-54b119b9
- **Timestamp:** 2026-06-02T15:03:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
