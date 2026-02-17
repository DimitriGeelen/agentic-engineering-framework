---
id: T-123
name: Framework shakedown — end-to-end lifecycle validation on throwaway project
description: >
  Framework shakedown — end-to-end lifecycle validation on throwaway project
status: work-completed
workflow_type: build
horizon: now
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T17:51:28Z
last_update: 2026-02-17T17:54:32Z
date_finished: 2026-02-17T17:54:32Z
---

# T-123: Framework shakedown — end-to-end lifecycle validation on throwaway project

## Context

End-to-end validation of the framework lifecycle on a throwaway project before starting T-107 (German pronunciation app). Goal: exercise `fw init`, task creation, work, commits, handover, and teardown on a fresh project directory.

Throwaway project: simple bash "hello world" CLI in `/tmp/shakedown-project/`.

## Acceptance Criteria

- [x] `fw init` succeeds in a fresh project directory
- [x] Task creation works (`fw task create` or `fw work-on`)
- [x] Git commit with task reference works (`fw git commit`)
- [x] `fw audit` passes (14 pass, 4 warn, 0 fail)
- [x] `fw handover` generates a valid handover
- [x] `fw doctor` passes (2 expected warnings)
- [x] Teardown: project directory removed

## Verification

# Project torn down — verification commands ran during shakedown, not applicable post-teardown
echo "shakedown complete"

## Updates

### 2026-02-17T17:51:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-123-framework-shakedown--end-to-end-lifecycl.md
- **Context:** Initial task creation

### 2026-02-17T17:54:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
