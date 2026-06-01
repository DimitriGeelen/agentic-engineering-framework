---
id: T-894
name: "Add unit tests for .framework.yaml config tier in lib/config.sh"
description: >
  Add unit tests for .framework.yaml config tier in lib/config.sh

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [tests/unit/lib_config.bats]
related_tasks: []
created: 2026-04-05T13:26:38Z
last_update: 2026-04-05T13:27:53Z
date_finished: 2026-04-05T13:27:53Z
---

# T-894: Add unit tests for .framework.yaml config tier in lib/config.sh

## Context

T-891 added `.framework.yaml` as Tier 3 in fw_config and T-892 fixed the registry. Tests need to cover: fw_config reading from file, precedence (env > file > default), registry showing source=file, and _fw_config_file_val for flat and dotted keys.

## Acceptance Criteria

### Agent
- [x] Tests for `_fw_config_file_val` with flat keys
- [x] Tests for `_fw_config_file_val` with dotted keys
- [x] Tests for `fw_config` file tier precedence (env > file > default)
- [x] Tests for `fw_config_registry` source=file
- [x] All tests pass: `bats tests/unit/lib_config.bats`

## Verification

bats tests/unit/lib_config.bats

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

### 2026-04-05T13:26:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-894-add-unit-tests-for-frameworkyaml-config-.md
- **Context:** Initial task creation

### 2026-04-05T13:27:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
