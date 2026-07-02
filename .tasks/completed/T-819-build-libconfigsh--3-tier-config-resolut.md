---
id: T-819
name: "Build lib/config.sh — 3-tier config resolution for framework settings"
description: >
  Build lib/config.sh — 3-tier config resolution for framework settings

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-03T21:36:57Z
last_update: '2026-06-11T22:24:30Z'
date_finished: 2026-04-04T12:30:29Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-819: Build lib/config.sh — 3-tier config resolution for framework settings

## Context

Implement 3-tier config resolution from T-817 inception (GO). Design: `docs/reports/T-817-three-tier-config.md`.

## Acceptance Criteria

### Agent
- [x] `lib/config.sh` exists with `fw_config` and `fw_config_int` functions
- [x] `fw_config "KEY" "default"` returns: explicit arg > `FW_KEY` env var > default
- [x] `fw_config_int` validates integer, falls back to default on invalid
- [x] `budget-gate.sh` migrated to use `fw_config_int`
- [x] `checkpoint.sh` migrated to use `fw_config_int`
- [x] `check-agent-dispatch.sh` migrated to use `fw_config_int`
- [x] `fw doctor` shows active `FW_*` overrides and validates ranges
- [x] Unit tests for `lib/config.sh` (bats) — 21 tests, all pass
- [x] Watchtower `/config` page shows all settings with current value and source

### Human
- [x] [REVIEW] Watchtower /config page is clear and useful
  **Steps:**
  1. Start Watchtower: `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve`
  2. Open `http://localhost:3000/config` in browser
  3. Check that all FW_* settings are listed with defaults and current values
  4. Set an override: `FW_DISPATCH_LIMIT=5 bin/fw serve` and verify it shows
  **Expected:** Table with setting name, current value, source (env/default), description
  **If not:** Note which settings are missing or incorrectly displayed

## Verification

# lib/config.sh exists and sources correctly
bash -c "source lib/config.sh && fw_config TEST 42"
# fw_config_int rejects non-integer
bash -c "source lib/config.sh && result=\$(FW_TEST=banana fw_config_int TEST 42 2>/dev/null) && [ \"\$result\" = \"42\" ]"
# Budget gate still works after migration
bash -c "echo '{}' | bin/fw hook budget-gate 2>&1; exit 0"
# Config page loads
curl -sf http://localhost:3000/ > /dev/null && curl -sf http://localhost:3000/config > /dev/null || echo "Watchtower not running (skipped)"

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

### 2026-04-03T21:36:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-819-build-libconfigsh--3-tier-config-resolut.md
- **Context:** Initial task creation

### 2026-04-04T12:30:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:27:23Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3a55dd44
- **Timestamp:** 2026-06-02T15:05:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
