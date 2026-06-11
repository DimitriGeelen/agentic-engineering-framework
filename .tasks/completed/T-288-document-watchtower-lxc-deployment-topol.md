---
id: T-288
name: "Document Watchtower LXC deployment topology"
description: >
  Document Watchtower LXC deployment topology

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/check-active-task.sh]
related_tasks: []
created: 2026-03-03T11:43:24Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-03T11:47:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-288: Document Watchtower LXC deployment topology

## Context

Record Watchtower LXC deployment topology in session memory for quick reference. Also discovered and fixed a governance bypass: `check-active-task.sh` exempt paths used `*/.claude/*` which matched `/root/.claude/` — anchored to `$PROJECT_ROOT`. Existing runbook at `docs/deployment-runbook.md` already comprehensive.

## Acceptance Criteria

### Agent
- [x] Deployment topology recorded in session memory (`MEMORY.md`)
- [x] `check-active-task.sh` exempt paths anchored to `$PROJECT_ROOT` (security fix)
- [x] Fix verified: external `.claude/` paths blocked without active task

## Verification

grep -q "Production Deployment" /root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/MEMORY.md
grep -q 'PROJECT_ROOT.*\.context' agents/context/check-active-task.sh

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

### 2026-03-03T11:43:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-288-document-watchtower-lxc-deployment-topol.md
- **Context:** Initial task creation

### 2026-03-03T11:47:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-98432aec
- **Timestamp:** 2026-06-02T15:01:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
