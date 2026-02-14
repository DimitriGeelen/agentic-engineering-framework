---
id: T-046
name: Dashboard, project docs, and directives pages
description: >
  Build three strategic web UI pages. (1) Dashboard /: project overview with vision summary, success stage status, active work count, key stats from metrics. (2) Project docs /project and /project/:doc: list all foundational documents (001-Vision.md through 025-ArtifactDiscovery.md, FRAMEWORK.md), render markdown with sidebar showing related decisions, tasks, gaps for each spec. (3) Directives /directives: traceability hub showing each directive (D1-D4) with linked practices, decisions, experiments, gaps, and tasks. Uses directives.yaml from T-043. Design authority: 025-ArtifactDiscovery.md. Relevant sections: Web UI Pages (full set), Page Details table, The Directives Page Traceability Hub, Foundational Documents table. Depends on: T-043 (directive IDs), T-045 (web foundation).
status: captured
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:34:14Z
last_update: 2026-02-14T11:34:14Z
date_finished: null
---

# T-046: Dashboard, project docs, and directives pages

## Design Record

**Design authority:** [025-ArtifactDiscovery.md](../../025-ArtifactDiscovery.md)
**Relevant sections:** Web UI Pages table, The Directives Page Traceability Hub, Foundational Documents table

**Key decisions:**
- Dashboard shows vision summary, success stage, active task count, key stats
- /project lists all foundational docs (001-Vision through 025-ArtifactDiscovery, FRAMEWORK.md)
- /project/:doc renders markdown with sidebar of related decisions, tasks, gaps
- /directives is the traceability hub: each D1-D4 shows linked practices, decisions, experiments, gaps, tasks
- All pages are read-only

**Dependencies:** T-043 (directive IDs), T-045 (web foundation)

## Specification Record

### Acceptance Criteria
- [ ] `/` dashboard shows: project name, vision one-liner, success stage (1-4), active task count, completed task count, gap count, last session date
- [ ] `/project` lists all 0XX-*.md files + FRAMEWORK.md with name and one-line description
- [ ] `/project/:doc` renders markdown to HTML with sidebar showing related artifacts
- [ ] `/directives` shows D1-D4 from directives.yaml
- [ ] Each directive expands to show: practices (derived_from), decisions (directives_served), gaps, tasks (tagged)
- [ ] All cross-reference links are clickable (navigate to /tasks/:id, /decisions, etc.)

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T11:34:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-046-dashboard-project-docs-and-directives-pa.md
- **Context:** Initial task creation
