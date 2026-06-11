---
id: T-1508
name: "T-1506 build — Tier 0 idempotency sentinel + install-time hook dedup (layered
  fix a+b)"
description: >
  T-1506 build — Tier 0 idempotency sentinel + install-time hook dedup (layered fix
  a+b)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/check-tier0.sh]
related_tasks: []
created: 2026-04-26T11:38:01Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T11:44:21Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1508: T-1506 build — Tier 0 idempotency sentinel + install-time hook dedup (layered fix a+b)

## Context

Implements T-1506 GO decision (recorded 2026-04-26T11:32:42Z).

**Layer (b) — Tier 0 idempotency sentinel (`agents/context/check-tier0.sh`):**
On approval consumption, write `${APPROVAL_FILE}.consumed` with the consumed
hash + timestamp. Before blocking on missing approval, check `.consumed`: if
same hash + age < 5s, allow without re-blocking. Catches duplicate hook
firings within the same Bash invocation; expires fast enough that the next
legitimate command still requires a fresh approval.

**Layer (a) — DISCOVERED ALREADY IMPLEMENTED:**
T-1506 RCA proposed `lib/hooks_dedup.sh` + `fw doctor` warn + `fw upgrade --dedupe-hooks`.
Investigation during this build revealed the work is already complete:
- **T-1479** added duplicate detection in `fw upgrade` (lib/upgrade.sh:697-741)
- **T-1480** added duplicate warning in `fw doctor` (bin/fw:847-887) — same warning surface I would have added
- **T-1481** added remediation flag `fw upgrade --dedupe-user-hooks` (lib/upgrade.sh:12, 745-747)
- Bats coverage exists: `tests/unit/upgrade_dedupe_user_hooks.bats`, `upgrade_duplicate_hook_detection.bats`, `doctor_duplicate_hook_detection.bats`

Result: layer (a) is fully delivered; T-1508 reduces to layer (b) only. The
duplicate-hook condition that triggered T-1506 was already detected and
reportable on the human's machine via `fw doctor`. The latent bug was that
Tier 0 itself self-defeats UNDER duplicate firing — that's what layer (b) fixes.

## Acceptance Criteria

### Agent
- [x] `agents/context/check-tier0.sh` writes `${APPROVAL_FILE}.consumed` (hash + timestamp) on consumption AND short-circuits to allow when a matching `.consumed` sentinel exists with age < 5s for the same hash
- [x] Bats test: simulate two-call sequence (approve → invoke twice) and assert both invocations exit 0; second call must not write a new `.pending`
- [x] Bats test: sentinel expires — after 5s, second invocation BLOCKS as if no approval (sentinel must not silently re-allow stale approvals)
- [x] Bats test: sentinel for different command does NOT cross-allow (security preserved)
- [x] Bats test: safe (non-destructive) command unaffected by sentinel logic
- [x] Existing tier0 bats tests still pass (no regression — verified via `bats tests/unit/check_tier0_comment_stripping.bats`)
- [x] Discovery documented: layer (a) already exists from T-1479/T-1480/T-1481; this task scopes to layer (b) only

## Verification

bash -n agents/context/check-tier0.sh
bats tests/unit/tier0_idempotency.bats
bats tests/unit/check_tier0_comment_stripping.bats

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

### 2026-04-26T11:38:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1508-t-1506-build--tier-0-idempotency-sentine.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-90044fe7
- **Timestamp:** 2026-06-02T14:57:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T11:44:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** layer (b) tier0 sentinel landed (5/5 bats green); layer (a) discovered already complete via T-1479/T-1480/T-1481
