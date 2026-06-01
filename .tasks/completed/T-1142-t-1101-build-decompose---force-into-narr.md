---
id: T-1142
name: "T-1101 build: decompose --force into narrow bypass flags (--skip-sovereignty) in update-task.sh and inception.sh"
description: >
  T-1101 build: decompose --force into narrow bypass flags (--skip-sovereignty) in update-task.sh and inception.sh

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T09:58:48Z
last_update: 2026-04-12T10:05:06Z
date_finished: 2026-04-12T10:05:06Z
---

# T-1142: T-1101 build: decompose --force into narrow bypass flags (--skip-sovereignty) in update-task.sh and inception.sh

## Context

Build task from T-1101 inception (GO decision). RCA: `lib/inception.sh:314` silently passes `--force` to `update-task.sh`, bypassing P-010, P-011, and R-033. Fix: decompose `--force` into narrow flags. See `docs/reports/T-1101-fw-inception-decide-force-rca.md`.

## Acceptance Criteria

### Agent
- [x] update-task.sh accepts 4 narrow flags: --skip-sovereignty, --skip-acceptance-criteria, --skip-verification, --skip-human-ownership
- [x] --force is deprecated alias that sets all 4 narrow flags and prints deprecation warning
- [x] Each gate function (sovereignty, AC, verification, ownership) checks only its own narrow flag
- [x] lib/inception.sh uses --skip-sovereignty instead of --force
- [x] Gate bypass audit log: each bypass writes to .context/working/.gate-bypass-log.yaml
- [x] Invariant test: no --force in lib/ or agents/ code (except update-task.sh deprecated alias)
- [x] Existing tests still pass

## Verification

# update-task.sh accepts new flags
grep -q "skip-sovereignty" agents/task-create/update-task.sh
grep -q "skip-acceptance-criteria" agents/task-create/update-task.sh
grep -q "skip-verification" agents/task-create/update-task.sh
grep -q "skip-human-ownership" agents/task-create/update-task.sh
# inception.sh uses narrow flag
grep -q "skip-sovereignty" lib/inception.sh
# inception.sh does NOT use --force for task completion
bash -c '! grep -q "update-task.sh.*--force" lib/inception.sh'
# invariant test exists
test -f tests/lint/no-force-in-framework.bats
# invariant test passes
bats tests/lint/no-force-in-framework.bats

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

### 2026-04-12T09:58:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1142-t-1101-build-decompose---force-into-narr.md
- **Context:** Initial task creation

### 2026-04-12T10:05:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
