---
id: T-221
name: "Housekeeping — close G-010, fix subsystem card counts"
description: >
  Housekeeping — close G-010, fix subsystem card counts

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
related_tasks: []
created: 2026-02-20T09:18:57Z
last_update: '2026-06-11T22:24:11Z'
date_finished: 2026-02-20T09:20:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-221: Housekeeping — close G-010, fix subsystem card counts

## Context

G-010 (Agent/Human AC split) was built in T-193 but gap never formally closed. Subsystem card counts were static in subsystems.yaml, drifting from actual component counts.

## Acceptance Criteria

### Agent
- [x] G-010 status changed to closed in gaps.yaml with evidence
- [x] Subsystem card counts use live data from subsystem_counts dict instead of static YAML
- [x] gaps.yaml parses correctly

## Verification

python3 -c "import yaml; d=yaml.safe_load(open('.context/project/gaps.yaml')); g10=[g for g in d['gaps'] if g['id']=='G-010'][0]; assert g10['status']=='closed', f'G-010 not closed: {g10[\"status\"]}'"
python3 -c "import urllib.request; r=urllib.request.urlopen('http://localhost:3000/fabric'); assert b'Component Fabric' in r.read()"

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

### 2026-02-20T09:18:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-221-housekeeping--close-g-010-fix-subsystem-.md
- **Context:** Initial task creation

### 2026-02-20T09:20:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2932e183
- **Timestamp:** 2026-06-02T15:01:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
