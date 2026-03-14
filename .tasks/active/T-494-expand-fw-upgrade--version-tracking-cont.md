---
id: T-494
name: "Expand fw upgrade — version tracking, context dir sync, E2E test"
description: >
  Expand fw upgrade to: (1) record framework VERSION in .framework.yaml on upgrade, (2) create new .context/ subdirs if missing, (3) add E2E upgrade test to fw self-test. From T-434 inception GO (Option A).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [upgrade, testing]
components: [bin/fw, lib/upgrade.sh]
related_tasks: []
created: 2026-03-14T20:05:30Z
last_update: 2026-03-14T20:14:58Z
date_finished: 2026-03-14T20:14:58Z
---

# T-494: Expand fw upgrade — version tracking, context dir sync, E2E test

## Context

From T-434 inception GO (Option A). Extends existing `lib/upgrade.sh` with version tracking and completeness.
Research: `docs/reports/T-434-upgrade-process-inception.md`.

## Acceptance Criteria

### Agent
- [x] `fw upgrade` records framework VERSION in `.framework.yaml` after successful upgrade
- [x] `fw upgrade` creates new `.context/` subdirs if missing (bus, scans, inbox, qa)
- [x] `fw upgrade` shows version comparison (project pinned vs framework current)
- [x] E2E upgrade test validates full upgrade flow in temp project
- [x] E2E test is integrated into `fw self-test`

### Human
- [ ] [RUBBER-STAMP] Run `fw upgrade --dry-run` on a test project
  **Steps:**
  1. Create temp project: `mkdir /tmp/test-proj && cd /tmp/test-proj && fw init`
  2. Run `./bin/fw upgrade /tmp/test-proj --dry-run`
  3. Verify output shows version tracking
  **Expected:** Shows what would change, includes version info
  **If not:** Note the error message

## Verification

grep -q "fw_version" lib/upgrade.sh
grep -q "context_dirs" lib/upgrade.sh || grep -q "bus\|scans\|inbox" lib/upgrade.sh
test -f tests/e2e/upgrade-test.sh
bash tests/e2e/upgrade-test.sh

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

### 2026-03-14T20:05:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-494-expand-fw-upgrade--version-tracking-cont.md
- **Context:** Initial task creation

### 2026-03-14T20:08:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-14T20:14:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
