---
id: T-1277
name: "Fix unbounded git push in handover auto-trigger (4h stall RCA)"
description: >
  handover.sh runs `git push` with no network timeout. When invoked from
  checkpoint.sh auto-handover (PostToolUse hook) or pre-compact.sh, a slow
  or unreachable remote (e.g. onedev.docker.ring20.geelenandcompany.com)
  stalls the hook for hours — freezing the Claude Code session until the
  git transport stack gives up. Explains observed 4h session stalls.
status: work-completed
workflow_type: build
owner: human
horizon:
tags: [bug, hooks, handover, performance]
components:
  - agents/handover/handover.sh
  - agents/context/checkpoint.sh
  - agents/context/pre-compact.sh
related_tasks: [T-136, T-1144]
created: 2026-04-17T09:40:00Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-04-18T23:37:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1277: Fix unbounded git push in handover auto-trigger (4h stall RCA)

## Context

Multi-hour Claude Code session stalls observed with no obvious cause. Investigation traced to:

- `agents/handover/handover.sh:759` pushes to every git remote with no timeout, no `ConnectTimeout`, no `http.lowSpeedTime`.
- `agents/context/checkpoint.sh:162` auto-invokes `handover.sh --commit` at critical context (≥285K tokens) from the PostToolUse hook — i.e. **on every tool call** once the threshold is crossed.
- `agents/context/pre-compact.sh:33` does the same on `/compact`.

Two configured remotes:
- `github` (public, usually reachable)
- `onedev` → `onedev.docker.ring20.geelenandcompany.com` (internal, behind docker/VPN)

When `onedev` is unreachable, `git push` HTTPS transport can hang for **hours** before giving up. The PostToolUse hook waits on the push, Claude Code waits on the hook, user sees a completely frozen session. Reason for "4h stall" reported on 2026-04-17.

Evidence:
- Both remotes reachable in <5s now (`git ls-remote` test) — stall is intermittent, correlates with `onedev` availability
- Session `bc7a9a42` hit ~200K tokens (urgent/approaching critical) before user `/exit`ed — right at the trigger threshold
- Session `2c0f952f` shows 42 Edit attempts with 22 `BLOCKED` results — check-active-task retry loop burns tokens fast toward the critical threshold that arms this bug

## Acceptance Criteria

### Agent

- [x] `agents/handover/handover.sh` wraps `git push` with `timeout` (FW_HANDOVER_PUSH_TIMEOUT, default 15s)
- [x] FW_HANDOVER_PUSH_TIMEOUT env var read with `${FW_HANDOVER_PUSH_TIMEOUT:-15}` fallback
- [x] Test: bats deadhost case proves push to 192.0.2.1 returns within bound (<8s incl. timeout=5)
- [x] `checkpoint.sh` auto-handover path wraps the whole call in `timeout "$_ah_total_timeout"` (FW_HANDOVER_TOTAL_TIMEOUT, default 60s)
- [x] Bats unit test: `tests/unit/handover_push_timeout.bats` — 8 tests cover source invariants + behavioural deadhost case
- [x] CLAUDE.md `Configuration` table updated with `FW_HANDOVER_PUSH_TIMEOUT` AND `FW_HANDOVER_TOTAL_TIMEOUT`

### Human

- [x] [REVIEW] Verify on next real session that auto-handover at critical doesn't reintroduce the stall
  **Steps:**
  1. After fix deployed, run a session that crosses 285K tokens
  2. Observe that PostToolUse hook returns within ~20s even if `onedev` is down
  3. Check `.context/working/.compact-log` for auto-handover event with timing
  **Expected:** Auto-handover completes within bounded time, non-blocking push failure logged as warning
  **If not:** Capture transcript and commit ID; re-open task

## Verification

# Shell commands that MUST pass before work-completed.
grep -q 'timeout.*git.*push\|http.lowSpeedTime' agents/handover/handover.sh
bats tests/unit/handover_push_timeout.bats
grep -q 'FW_HANDOVER_PUSH_TIMEOUT' CLAUDE.md

## Decisions

<!-- Record when choosing between alternatives -->

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs verified — both push timeout (15s) and total auto-handover timeout (60s) are wrapped, env var fallbacks are correct, and an 8-test bats suite covers source invariants + a deadhost behavioural case. CLAUDE.md Configuration table updated. The Human AC is a forward-looking observation ("verify on next real session that auto-handover at critical doesn't reintroduce the stall") — it cannot be checked at completion time, only after a real critical-budget event.

**Evidence:**
- agents/handover/handover.sh wraps `git push` with `timeout $FW_HANDOVER_PUSH_TIMEOUT`
- agents/context/checkpoint.sh wraps the auto-handover call with `timeout $FW_HANDOVER_TOTAL_TIMEOUT`
- tests/unit/handover_push_timeout.bats — 8 tests including deadhost (192.0.2.1) returns within bound
- CLAUDE.md Configuration section lists both env vars

## Updates

### 2026-04-17T09:40:00Z — task-created [manual]
- **Action:** Created task directly (fw work-on hung at 30s — likely related slowness)
- **Context:** See docs/reports/issue-report-4h-timeout.md for full RCA write-up

### 2026-04-18T23:33:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T23:37:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Push timeout + total timeout shipped, 8/8 bats green, CLAUDE.md updated

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c3f19aff
- **Timestamp:** 2026-06-02T14:56:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
