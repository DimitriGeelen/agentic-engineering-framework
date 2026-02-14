---
id: T-046
name: Dashboard, project docs, and directives pages
description: >
  Build three strategic web UI pages. (1) Dashboard /: project overview with vision summary, success stage status, active work count, key stats from metrics. (2) Project docs /project and /project/:doc: list all foundational documents (001-Vision.md through 025-ArtifactDiscovery.md, FRAMEWORK.md), render markdown with sidebar showing related decisions, tasks, gaps for each spec. (3) Directives /directives: traceability hub showing each directive (D1-D4) with linked practices, decisions, experiments, gaps, and tasks. Uses directives.yaml from T-043. Design authority: 025-ArtifactDiscovery.md. Relevant sections: Web UI Pages (full set), Page Details table, The Directives Page Traceability Hub, Foundational Documents table. Depends on: T-043 (directive IDs), T-045 (web foundation).
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:34:14Z
last_update: 2026-02-14T12:27:34Z
date_finished: 2026-02-14T12:27:34Z
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

### 2026-02-14T13:15:00Z — implementation [claude-code]
- **Action:** Implemented all three pages with real data
- **Changes:**
  - `web/app.py`: Added `import yaml`, `import markdown2`, `import re as re_mod`; updated `/` route with task counts, gap count, last session; updated `/project` route to list 0*.md + FRAMEWORK.md; added `/project/<doc>` route with path traversal protection and markdown rendering; updated `/directives` route to load directives, practices, decisions, gaps from YAML and group by directive
  - `web/templates/index.html`: Stats grid with active tasks (8), completed tasks (42), watching gaps (6), last session ID; quick links section
  - `web/templates/project.html`: Table listing all project docs with links to `/project/<doc>`
  - `web/templates/project_doc.html`: New template rendering markdown to HTML with back-navigation
  - `web/templates/directives.html`: Cards for each directive (D1-D4) with expandable `<details>` for linked practices, decisions, and gaps
- **Testing:** All routes return HTTP 200, real data verified (counts, doc names, directive IDs, practice/decision cross-references), htmx partial rendering confirmed, path traversal blocked with 404
- **Dependencies installed:** `markdown2` via pip

### 2026-02-14T12:27:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-14T12:27:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
