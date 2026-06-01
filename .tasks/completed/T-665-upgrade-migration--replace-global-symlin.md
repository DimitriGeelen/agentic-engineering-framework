---
id: T-665
name: "Upgrade migration — replace global symlink with shim during fw upgrade"
description: >
  Phase 3 of T-662: Modify lib/upgrade.sh step 4c to detect global install symlinks and replace them with the fw-shim. Print one-time migration notice. Keep T-660 sync as fallback for users who haven't upgraded yet. Related: T-662, T-663, T-664.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [T-662, upgrade, shim]
components: []
related_tasks: []
created: 2026-03-28T17:14:38Z
last_update: 2026-03-28T17:16:05Z
date_finished: 2026-03-28T17:16:05Z
---

# T-665: Upgrade migration — replace global symlink with shim during fw upgrade

## Context

Phase 3 of T-662 (GO). Replace step 4c in `lib/upgrade.sh` (global install sync from T-660) with shim migration. When `~/.local/bin/fw` is a symlink to the global install, replace it with the fw-shim. Keep T-660 global sync as fallback for users who haven't run the shim migration.

## Acceptance Criteria

### Agent
- [x] Step 4c in `lib/upgrade.sh` detects old symlinks and replaces with shim
- [x] Migration prints one-time notice explaining the change
- [x] T-660 global script sync still runs (fallback until shim is universal)
- [x] Vendored `lib/upgrade.sh` synced

## Verification

grep -q 'fw-shim' lib/upgrade.sh
grep -q 'Shim migration' lib/upgrade.sh

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

### 2026-03-28T17:14:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-665-upgrade-migration--replace-global-symlin.md
- **Context:** Initial task creation

### 2026-03-28T17:16:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
