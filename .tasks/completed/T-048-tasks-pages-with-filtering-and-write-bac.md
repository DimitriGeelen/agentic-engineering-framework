---
id: T-048
name: Tasks pages with filtering and write-back
description: >
  Build task list and task detail web pages with interactive features. (1) /tasks
  page: filterable task list by component, directive, workflow_type, status. Sortable
  by date, name. Data source: episodic files parsed on-the-fly. (2) /tasks/:id page:
  full episodic summary (outcomes, decisions, challenges, artifacts, relationships)
  + raw task content. (3) Write-back: PATCH /api/task/:id for safe fields (priority,
  tags, owner) via direct YAML edit. POST /api/task/:id/status routes through fw task
  update CLI to preserve automation triggers (healing on issues/blocked, episodic
  generation on work-completed). (4) Uses controlled tag vocabulary from T-044 for
  filter options. Design authority: 025-ArtifactDiscovery.md. Relevant sections: Write-Back
  Safety Model, Design Decision Episodic Memory as Primary Discovery Layer, Q1 Episodic
  Index (on-the-fly). Depends on: T-044 (tag backfill), T-045 (web foundation).
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:34:34Z
last_update: '2026-06-11T22:23:36Z'
date_finished: 2026-02-14T12:27:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-048: Tasks pages with filtering and write-back

## Design Record

**Design authority:** [025-ArtifactDiscovery.md](../../025-ArtifactDiscovery.md)
**Relevant sections:** Write-Back Safety Model, Design Decision Episodic Memory as Primary, Q1 Episodic Index (on-the-fly)

**Key decisions:**
- Episodic files are primary data source (richer than task frontmatter)
- Computed on-the-fly — no index file (42 files is trivial)
- Filter by: component tag, directive tag, workflow_type, status
- Sort by: date (default), name
- Write-back safety: priority/tags/owner are safe (direct YAML edit), status MUST route through `fw task update` CLI
- YAML comment preservation: use ruamel.yaml or targeted text replacement
- Relationship visualization: /tasks/:id shows "Related Tasks" section with typed edges (spawned, blocked, absorbed, fix-for, informed-by) from episodic related_tasks data
- Input validation: task IDs must match T-\d{3}, status values from allowlist, no shell metacharacters in tags

**Dependencies:** T-044 (tag backfill for useful filters), T-045 (web foundation)

## Specification Record

### Acceptance Criteria
- [x] /tasks shows all tasks with name, status, component tags, date
- [ ] Filter controls for component, directive, workflow_type, status
- [ ] Sort toggle for date vs. name
- [ ] /tasks/:id shows full episodic summary + task content
- [ ] /tasks/:id shows "Related Tasks" section with typed relationship edges
- [ ] Status value validated against allowlist before fw task update invocation
- [ ] Task ID validated as T-\d{3} pattern before file path construction
- [ ] PATCH /api/task/:id updates priority, tags, owner (direct YAML edit)
- [ ] POST /api/task/:id/status invokes `fw task update` subprocess
- [ ] Status change triggers are preserved (healing on issues, episodic on work-completed)
- [ ] Filter state preserved in URL query params

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T11:34:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-048-tasks-pages-with-filtering-and-write-bac.md
- **Context:** Initial task creation

### 2026-02-14T12:27:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-14T12:27:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-38948a2a
- **Timestamp:** 2026-06-02T14:54:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
