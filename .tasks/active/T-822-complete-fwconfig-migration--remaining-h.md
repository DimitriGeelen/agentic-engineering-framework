---
id: T-822
name: "Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts"
description: >
  Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-03T22:51:09Z
last_update: 2026-04-03T23:04:29Z
date_finished: null
---

# T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts

## Context

Follow-on from T-819 (lib/config.sh). 8 files still hardcode settings that should use fw_config. Also adds 4 new settings to FW_CONFIG_REGISTRY and syncs Watchtower /config page.

## Acceptance Criteria

### Agent
- [x] `bin/watchtower.sh` uses `fw_config "PORT" 3000` for port default
- [x] `lib/keylock.sh` uses `fw_config_int "KEYLOCK_TIMEOUT" 300`
- [x] `lib/review.sh` uses `fw_config "PORT" 3000` for Watchtower URL fallback
- [x] `agents/termlink/termlink.sh` uses `fw_config_int` for spawn/worker timeouts
- [x] `agents/context/pre-compact.sh` uses `fw_config_int` for handover dedup cooldown
- [x] `agents/audit/audit.sh` uses `fw_config` for health check port
- [x] `FW_CONFIG_REGISTRY` updated with new settings (KEYLOCK_TIMEOUT, TERMLINK_WORKER_TIMEOUT, HANDOVER_DEDUP_COOLDOWN)
- [x] Watchtower `/config` page updated to show new settings
- [x] All 518+ unit tests still pass
- [x] `fw doctor` shows no new warnings

### Human
- [ ] [RUBBER-STAMP] Watchtower /config page shows new settings
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve`
  2. Open `http://localhost:3000/config`
  3. Verify new settings (KEYLOCK_TIMEOUT, TERMLINK_WORKER_TIMEOUT, HANDOVER_DEDUP_COOLDOWN) appear
  **Expected:** New settings visible with correct defaults and descriptions
  **If not:** Note which settings are missing

## Verification

# lib/config.sh sources correctly
bash -c "source lib/config.sh && fw_config PORT 3000"
# Registry has new settings
bash -c "source lib/config.sh && fw_config_registry | grep -q KEYLOCK_TIMEOUT"
bash -c "source lib/config.sh && fw_config_registry | grep -q TERMLINK_WORKER_TIMEOUT"
# watchtower.sh sources config
grep -q "fw_config" bin/watchtower.sh
# keylock.sh uses fw_config
grep -q "fw_config_int" lib/keylock.sh
# review.sh uses fw_config
grep -q "fw_config" lib/review.sh
# Unit tests pass
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

### 2026-04-03T22:51:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-822-complete-fwconfig-migration--remaining-h.md
- **Context:** Initial task creation
