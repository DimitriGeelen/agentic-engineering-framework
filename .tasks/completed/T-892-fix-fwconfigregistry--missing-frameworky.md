---
id: T-892
name: "Fix fw_config_registry — missing .framework.yaml tier lookup"
description: >
  Fix fw_config_registry — missing .framework.yaml tier lookup

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/config.sh]
related_tasks: []
created: 2026-04-05T13:22:05Z
last_update: 2026-04-05T13:23:03Z
date_finished: 2026-04-05T13:23:03Z
---

# T-892: Fix fw_config_registry — missing .framework.yaml tier lookup

## Context

T-891 added `.framework.yaml` as Tier 3 in `fw_config()` resolution, but `fw_config_registry()` was not updated. It only checks env var vs default, missing the file tier. This means `fw doctor` and Watchtower `/config` don't show values from `.framework.yaml`.

## Acceptance Criteria

### Agent
- [x] `fw_config_registry()` checks `.framework.yaml` via `_fw_config_file_val` between env and default
- [x] Source reported as `file` when value comes from `.framework.yaml`

## Verification

grep -q '_fw_config_file_val' lib/config.sh
grep -q '"file"' lib/config.sh

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

### 2026-04-05T13:22:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-892-fix-fwconfigregistry--missing-frameworky.md
- **Context:** Initial task creation

### 2026-04-05T13:23:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
