---
id: T-252
name: "Fix unresolved C-XXX/F-XXX IDs in filtered fabric graph"
description: >
  Fix unresolved C-XXX/F-XXX IDs in filtered fabric graph

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [web/blueprints/fabric.py]
related_tasks: []
created: 2026-02-22T16:13:38Z
last_update: 2026-02-22T16:16:53Z
date_finished: 2026-02-22T16:16:53Z
---

# T-252: Fix unresolved C-XXX/F-XXX IDs in filtered fabric graph

## Context

When filtering the fabric dependency graph by subsystem, cross-subsystem dependency targets showed as raw IDs (C-008, F-001) with "unknown" type instead of resolved names. Bug: `fabric_graph()` passed the filtered component list as `all_components` to `_build_graph`, so the `id_to_name` map only contained same-subsystem components.

## Acceptance Criteria

### Agent
- [x] Filtered graph resolves cross-subsystem C-XXX/F-XXX IDs to component names
- [x] Dependency target nodes show correct type and subsystem grouping

## Verification

# Audit-filtered graph has no unknown-type nodes
curl -s "http://localhost:3000/fabric/graph?subsystem=audit" | grep -q "learnings-data"
curl -s "http://localhost:3000/fabric/graph?subsystem=audit" | grep -q "checkpoint"

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

### 2026-02-22T16:13:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-252-fix-unresolved-c-xxxf-xxx-ids-in-filtere.md
- **Context:** Initial task creation

### 2026-02-22T16:16:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
