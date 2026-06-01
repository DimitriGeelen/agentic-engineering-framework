---
id: T-889
name: "fw config set/get — read and write persistent settings in .framework.yaml"
description: >
  fw config set/get — read and write persistent settings in .framework.yaml

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/config-file.sh]
related_tasks: []
created: 2026-04-05T12:40:23Z
last_update: 2026-04-05T12:44:05Z
date_finished: 2026-04-05T12:44:05Z
---

# T-889: fw config set/get — read and write persistent settings in .framework.yaml

## Context

Add `fw config set KEY VALUE` and `fw config get KEY` to read/write persistent settings in `.framework.yaml`. Foundation for T-885 (configurable ports). Uses `ruamel.yaml` for round-trip YAML editing (preserves comments/ordering).

## Acceptance Criteria

### Agent
- [x] `fw config set watchtower.port 3001` writes to `.framework.yaml`
- [x] `fw config get watchtower.port` reads from `.framework.yaml`
- [x] `fw config list` shows all custom settings
- [x] Dot-notation for nested keys works (`watchtower.port` → `watchtower: { port: 3001 }`)
- [x] Missing `.framework.yaml` gives clear error

## Verification

# lib/config-file.sh exists and is sourceable
test -f lib/config-file.sh
# fw routes config subcommand
bin/fw config --help 2>&1 | grep -q "set\|get"

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

### 2026-04-05T12:40:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-889-fw-config-setget--read-and-write-persist.md
- **Context:** Initial task creation

### 2026-04-05T12:44:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
