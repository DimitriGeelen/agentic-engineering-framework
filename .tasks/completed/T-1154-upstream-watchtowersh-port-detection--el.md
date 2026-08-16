---
id: T-1154
name: "Upstream watchtower.sh port detection — eliminate all hardcoded port 3000 defaults
  across framework"
description: >
  Upstream watchtower.sh port detection — eliminate all hardcoded port 3000 defaults
  across framework

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T11:38:30Z
last_update: '2026-08-16T22:24:24Z'
date_finished: 2026-04-12T11:43:59Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1154: Upstream watchtower.sh port detection — eliminate all hardcoded port 3000 defaults across framework

## Context

`lib/watchtower.sh` with `_watchtower_url()` was created in consumer `/opt/termlink` (T-974) but never upstreamed to the framework. The framework's `lib/review.sh`, `lib/verify-acs.sh`, and `agents/audit/audit.sh` all have their own inline port detection that defaults to 3000. Every `fw upgrade` overwrites any consumer fix. Result: consumer Watchtower on ports != 3000 (e.g., 3002) are never found — `fw task review` sends human to wrong port, 404s, frustration.

Root cause: T-1105 chokepoint violation — multiple independent port-detection implementations instead of one shared helper.

Sites to fix:
1. `lib/review.sh:40-56` — inline PID+host+default detection
2. `lib/verify-acs.sh:53-54` — inline `fw_config PORT 3000`
3. `agents/audit/audit.sh:2717` — inline `fw_config PORT 3000`
4. `bin/watchtower.sh:20` — PID_FILE uses FRAMEWORK_ROOT, should use PROJECT_ROOT
5. `bin/fw:992-994` — doctor smoke test uses `${FW_PORT:-3000}`

## Acceptance Criteria

### Agent
- [x] `lib/watchtower.sh` exists in framework with `_watchtower_url` and `_watchtower_open` functions
- [x] `lib/review.sh` uses `_watchtower_url` — no inline port detection
- [x] `lib/verify-acs.sh` uses `_watchtower_url` — no inline port fallback to 3000
- [x] `agents/audit/audit.sh` uses `_watchtower_url` — no inline port fallback to 3000
- [x] `bin/watchtower.sh` PID_FILE uses PROJECT_ROOT not FRAMEWORK_ROOT
- [x] `grep -rn 'fw_config.*PORT.*3000' lib/review.sh lib/verify-acs.sh agents/audit/audit.sh` returns no matches
- [x] `fw task review T-1154` resolves correct port (not hardcoded 3000)

## Verification

bash -c 'grep -q "_watchtower_url" lib/review.sh'
bash -c 'grep -q "_watchtower_url" lib/verify-acs.sh'
bash -c '! grep -q "fw_config.*PORT.*3000" lib/review.sh'
bash -c '! grep -q "fw_config.*PORT.*3000" lib/verify-acs.sh'
bash -c 'test -f lib/watchtower.sh'
bash -c 'grep -q "_watchtower_url" lib/watchtower.sh'

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

### 2026-04-12T11:38:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1154-upstream-watchtowersh-port-detection--el.md
- **Context:** Initial task creation

### 2026-04-12T11:43:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ec87a0cb
- **Timestamp:** 2026-06-02T14:55:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#4 (Agent)** — `agents/audit/audit.sh` uses `_watchtower_url` — no inline port fallback to 3000
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: `agents/audit/audit.sh` uses `_watchtower_url` — no inline port fallback to 3000`
- **AC#5 (Agent)** — `bin/watchtower.sh` PID_FILE uses PROJECT_ROOT not FRAMEWORK_ROOT
  - **AC-verify-mismatch** (narrow, heuristic) — `path=bin/watchtower.sh in: `bin/watchtower.sh` PID_FILE uses PROJECT_ROOT not FRAMEWORK_ROOT`
- **AC#6 (Agent)** — `grep -rn 'fw_config.*PORT.*3000' lib/review.sh lib/verify-acs.sh agents/audit/audit.sh` returns no matches
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: `grep -rn 'fw_config.*PORT.*3000' lib/review.sh lib/verify-acs.sh agents/audit/audit.sh` returns no matches`
