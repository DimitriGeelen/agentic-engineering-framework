---
id: T-1277
name: "Fix unbounded git push in handover auto-trigger (4h stall RCA)"
description: >
  handover.sh runs `git push` with no network timeout. When invoked from
  checkpoint.sh auto-handover (PostToolUse hook) or pre-compact.sh, a slow
  or unreachable remote (e.g. onedev.docker.ring20.geelenandcompany.com)
  stalls the hook for hours — freezing the Claude Code session until the
  git transport stack gives up. Explains observed 4h session stalls.
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bug, hooks, handover, performance]
components:
  - agents/handover/handover.sh
  - agents/context/checkpoint.sh
  - agents/context/pre-compact.sh
related_tasks: [T-136, T-1144]
created: 2026-04-17T09:40:00Z
last_update: 2026-04-17T09:40:00Z
date_finished: null
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

- [ ] `agents/handover/handover.sh:759` wraps `git push` with `timeout 15` (or uses `git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 push`)
- [ ] `fw_config_int "HANDOVER_PUSH_TIMEOUT" 15` added as configurable (FW_HANDOVER_PUSH_TIMEOUT env var, default 15s)
- [ ] Test: simulate unreachable remote (`git remote add deadremote https://192.0.2.1/x.git`) → `fw handover --commit` returns within 20s, not hours
- [ ] `checkpoint.sh` auto-handover path wraps the whole call in a bounded `timeout` as belt-and-braces
- [ ] Bats unit test: `tests/unit/handover_push_timeout.bats` exercising the timeout path
- [ ] CLAUDE.md `Configuration` table updated with `FW_HANDOVER_PUSH_TIMEOUT`

### Human

- [ ] [REVIEW] Verify on next real session that auto-handover at critical doesn't reintroduce the stall
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

## Updates

### 2026-04-17T09:40:00Z — task-created [manual]
- **Action:** Created task directly (fw work-on hung at 30s — likely related slowness)
- **Context:** See docs/reports/issue-report-4h-timeout.md for full RCA write-up
