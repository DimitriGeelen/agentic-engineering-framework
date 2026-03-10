---
id: T-401
name: "Framework hardening: fix orphaned fabric cards, register concerns.yaml"
description: >
  T-397 consolidated gaps+risks into concerns.yaml but left 3 orphaned fabric cards (gaps.yaml, issues.yaml, risks.yaml) and 1 unregistered component (concerns.yaml). Fix fabric drift and update edges.

status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-10T09:44:29Z
last_update: 2026-03-10T12:43:43Z
date_finished: 2026-03-10T12:43:43Z
---

# T-401: Framework hardening: fix orphaned fabric cards, register concerns.yaml

## Context

T-397 consolidated gaps.yaml, issues.yaml, and risks.yaml into a unified concerns.yaml. This left 3 orphaned fabric cards and 1 unregistered component. This task cleans up the fabric topology.

## Acceptance Criteria

### Agent
- [x] Orphaned card `context-project-gaps.yaml` deleted
- [x] Orphaned card `context-project-issues.yaml` deleted
- [x] Orphaned card `context-project-risks.yaml` deleted
- [x] New card `context-project-concerns.yaml` registered with correct subsystem, purpose, and edges
- [x] `fw fabric drift` reports 0 unregistered, 0 orphaned, 0 stale

## Verification

# Drift report clean
fw fabric drift 2>&1 | grep -q "unregistered: 0, orphaned: 0, stale: 0"
# Orphaned cards removed
test ! -f .fabric/components/context-project-gaps.yaml
test ! -f .fabric/components/context-project-issues.yaml
test ! -f .fabric/components/context-project-risks.yaml
# New card exists and parses
python3 -c "import yaml; yaml.safe_load(open('.fabric/components/context-project-concerns.yaml'))"

## Decisions

None — straightforward cleanup.

## Updates

### 2026-03-10T09:44:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-401-framework-hardening-fix-orphaned-fabric-.md
- **Context:** Initial task creation

### 2026-03-10T12:39:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-10T12:43:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
