---
id: T-171
name: "Docs page — auto-discover and categorize project docs"
description: >
  Docs page — auto-discover and categorize project docs

status: work-completed
workflow_type: build
owner: claude-code
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T18:06:27Z
last_update: 2026-02-18T18:08:05Z
date_finished: 2026-02-18T18:08:05Z
---

# T-171: Docs page — auto-discover and categorize project docs

## Context

Build task from T-133 inception (GO). Expand Docs page to auto-discover docs from standard locations.

## Acceptance Criteria

- [x] Auto-discover docs from root, docs/, docs/plans/, agents/*/AGENT.md
- [x] Categorize into Governance, Design, Agents, Project groups
- [x] CLAUDE.md and FRAMEWORK.md appear as top-level governance docs
- [x] Subdirectory docs render correctly via -- path separator
- [x] Grid layout shows all categories on one page

## Verification

curl -sf http://localhost:3000/project | grep -q "Governance"
curl -sf http://localhost:3000/project | grep -q "Design"
curl -sf http://localhost:3000/project | grep -q "Agents"
curl -sf http://localhost:3000/project/CLAUDE | grep -q "Core Principle"
curl -sf http://localhost:3000/project/docs--cycle2-protocol | grep -q "html"
curl -sf http://localhost:3000/project/agents--audit--AGENT | grep -q "html"

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

### 2026-02-18T18:06:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-171-docs-page--auto-discover-and-categorize-.md
- **Context:** Initial task creation

### 2026-02-18T18:08:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
