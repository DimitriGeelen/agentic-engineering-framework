---
id: T-288
name: "Document Watchtower LXC deployment topology"
description: >
  Document Watchtower LXC deployment topology

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-03T11:43:24Z
last_update: 2026-03-03T11:46:51Z
date_finished: null
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
