---
id: T-865
name: "Fix Fabric Explorer naming — use project_name in title"
description: >
  Fix Fabric Explorer naming — use project_name in title

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/app.py, web/templates/fabric_explorer.html]
related_tasks: []
created: 2026-04-04T20:39:09Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-04T20:43:03Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
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
      F2: 2
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=2 (body:component-fabric-minor)
    rubric_sha: e4a00f38e801
---

# T-865: Fix Fabric Explorer naming — use project_name in title

## Context

T-854 added `project_name` Jinja global but Fabric Explorer h1 still says "Fabric Explorer" (generic). OpenClaw's instance at :1500 shows "OpenClaw Fabric Explorer" — project-specific. Fix: use `{{ project_name }}` in the template.

## Acceptance Criteria

### Agent
- [x] Fabric Explorer h1 includes `{{ project_name }}`
- [x] curl localhost:3000/fabric/graph shows "Agentic Engineering Framework Fabric Explorer"

## Verification

curl -sf http://localhost:3000/fabric/graph -o /tmp/t865.html && grep -q 'Agentic Engineering Framework' /tmp/t865.html

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

### 2026-04-04T20:39:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-865-fix-fabric-explorer-naming--use-projectn.md
- **Context:** Initial task creation

### 2026-04-04T20:43:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9fae6a40
- **Timestamp:** 2026-06-02T15:05:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
