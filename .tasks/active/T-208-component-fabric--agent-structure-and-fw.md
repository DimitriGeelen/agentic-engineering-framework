---
id: T-208
name: "Component Fabric — agent structure and fw routing"
description: >
  Create agents/fabric/ directory structure with fabric.sh dispatcher and lib/ subdirectory. Wire fw fabric routing in bin/fw. Follows architecture from T-191 Phase 4 (docs/reports/T-191-cf-enforcement-design.md).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [component-fabric, infrastructure]
related_tasks: []
created: 2026-02-20T07:13:52Z
last_update: 2026-02-20T07:13:52Z
date_finished: null
---

# T-208: Component Fabric — agent structure and fw routing

## Context

Build task from T-191 inception (GO). Design: `docs/reports/T-191-cf-enforcement-design.md`.

## Acceptance Criteria

### Agent
- [x] `agents/fabric/` directory with `fabric.sh` dispatcher and `lib/` subdirectory
- [x] `fw fabric` routed in `bin/fw`
- [x] All 12 subcommands dispatch correctly (register, scan, search, get, deps, impact, blast-radius, ui, drift, validate, overview, subsystem, stats)
- [x] `fw fabric help` shows usage
- [x] `fw fabric search`, `overview`, `stats`, `impact`, `deps`, `ui`, `blast-radius`, `drift` produce correct output against prototype cards

## Verification

fw fabric help | grep -q "Component topology system"
fw fabric search learnings | grep -q "add-learning"
fw fabric overview | grep -q "subsystems"
fw fabric stats | grep -q "Components:"
fw fabric impact agents/context/lib/learning.sh | grep -q "downstream"

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

### 2026-02-20T07:13:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-208-component-fabric--agent-structure-and-fw.md
- **Context:** Initial task creation
