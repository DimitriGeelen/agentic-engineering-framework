---
id: T-891
name: "Add .framework.yaml as persistent tier in fw_config resolution"
description: >
  Add .framework.yaml as persistent tier in fw_config resolution

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-05T12:46:56Z
last_update: 2026-04-05T12:46:56Z
date_finished: null
---

# T-891: Add .framework.yaml as persistent tier in fw_config resolution

## Context

`lib/config.sh` has 3 tiers: CLI arg > env var > default. Add a 4th tier between env var and default: read from `.framework.yaml` config section. This makes `fw config set watchtower.port 3001` take effect for all tools using `fw_config`.

## Acceptance Criteria

### Agent
- [x] `fw_config` reads from `.framework.yaml` when env var is not set
- [x] Resolution order: CLI arg > env var > .framework.yaml > default
- [x] Existing behavior unchanged when `.framework.yaml` has no custom settings
- [x] All 524 unit tests still pass

## Verification

bats tests/unit/lib_config.bats
grep -q 'framework.yaml\|_fw_config_file' lib/config.sh

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

### 2026-04-05T12:46:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-891-add-frameworkyaml-as-persistent-tier-in-.md
- **Context:** Initial task creation
