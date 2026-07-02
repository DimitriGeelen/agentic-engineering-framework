---
id: T-822
name: "Complete fw_config migration — remaining hardcoded settings in hooks and lib
  scripts"
description: >
  Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-03T22:51:09Z
last_update: '2026-06-11T22:24:30Z'
date_finished: 2026-04-03T23:10:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] Watchtower /config page shows new settings (reclassified from Human RUBBER-STAMP per T-954)

### Human

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
curl -sf http://localhost:3000/config | grep -q "Settings\|Configuration"

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

### 2026-04-03T23:10:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-18a2c1cf
- **Timestamp:** 2026-06-02T15:05:04Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `bash -c "source lib/config.sh && fw_config_registry | grep -q KEYLOCK_TIMEOUT"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `bash -c "source lib/config.sh && fw_config_registry | grep -q TERMLINK_WORKER_TIMEOUT"`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 14
     - evidence: `curl -sf http://localhost:3000/config | grep -q "Settings\|Configuration"`
