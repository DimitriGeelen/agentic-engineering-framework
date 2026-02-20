---
id: T-221
name: "Housekeeping — close G-010, fix subsystem card counts"
description: >
  Housekeeping — close G-010, fix subsystem card counts

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-20T09:18:57Z
last_update: 2026-02-20T09:20:24Z
date_finished: 2026-02-20T09:20:24Z
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
