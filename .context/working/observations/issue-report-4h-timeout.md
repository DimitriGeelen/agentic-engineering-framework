---
type: issue-report
title: "4-hour Claude Code session stall — unbounded git push in auto-handover"
reported: 2026-04-17
reporter: human (dimitrigeelen@hotmail.com)
investigated_by: agent
severity: high
frequency: intermittent (correlates with onedev remote availability)
related_task: T-1277
status: rca-complete
tags: [bug, hooks, handover, network, rca]
---

# Issue Report — 4h Session Stall (RCA)

## Symptom

Claude Code sessions in `/opt/999-Agentic-Engineering-Framework` stall for multi-hour durations with no visible progress. User perceives sessions as "stuck" starting around 20–80 tool calls or at high context.

## Root cause (confirmed)

`agents/handover/handover.sh:759` runs `git push` against every configured remote with **no `timeout`, no `ConnectTimeout`, no `http.lowSpeedTime`**. When invoked from a PostToolUse hook, an unresponsive remote freezes the whole Claude Code session until the git HTTPS transport gives up — which with kernel-default TCP retries + TLS handshake timeouts can take **hours**.

### Call chain

1. `agents/context/checkpoint.sh` — PostToolUse hook, matcher `""` (runs on **every tool call**).
2. At tokens ≥ `TOKEN_CRITICAL` (95% of `FW_CONTEXT_WINDOW`, default 285K) it auto-invokes `handover.sh --commit` (`checkpoint.sh:162`).
3. `handover.sh:757-765` iterates `git remote` and runs:
   ```bash
   git -C "$PROJECT_ROOT" push --follow-tags "$remote_name" HEAD 2>&1
   ```
   with no timeout wrapper.
4. If any remote hangs, the hook blocks. Claude Code waits on the hook. Session frozen.

Same bug via `agents/context/pre-compact.sh:33` (fires on `/compact`) and direct `fw handover --commit`.

### Configured remotes in this repo

- `github` → `github.com/DimitriGeelen/agentic-engineering-framework.git` (public, usually fine)
- `onedev` → `onedev.docker.ring20.geelenandcompany.com/...` (internal, behind docker/VPN — **the likely culprit when down**)

## Contributing (not causal, but accelerate reaching the trigger)

These don't cause the stall but speed the session into the `TOKEN_CRITICAL` band where the bug arms:

- **Stale `focus.yaml` (`current_task: null`)** — every Write/Edit tool call hits `check-active-task.sh` exit-2 (`BLOCKED: No active task`). Agent often retries with variants, burning tokens. Evidence: session `2c0f952f-edb2` = 42 Edit attempts, 22 BLOCKED results.
- **Slow PreToolUse hook chain** — timed on a plain `Bash`:
  - `budget-gate.sh`: ~3.3s (tails 10MB of current JSONL, runs Python twice)
  - `check-active-task.sh`: ~2.6s
  - `check-project-boundary.sh`: ~1.6s
  - cumulative ~7s per tool call → user perception of frozen session even when hooks aren't blocking
- **1.3 GB of old JSONLs** in `~/.claude/projects/-opt-999-Agentic-Engineering-Framework/` (largest 151 MB, 68 MB, 59 MB). Amplifies budget-gate slow path.
- **Claude Code system-reminder pushing `TaskCreate`/`TodoWrite`** — framework already blocks these via `block-task-tools.sh`, but each occurrence costs a tool round-trip and context tokens, and can loop if agent obeys reminder on older models.

## Evidence

- Recent aborted sessions (17K, 12K, 16K JSONL files from 2026-04-17) all show agent interrupted on first Bash tool call via permission-prompt denial — symptom is "stuck at 20–80 tokens" in the status line.
- Session `bc7a9a42` reached ~200K tokens (urgent level, approaching `TOKEN_CRITICAL`) before user `/exit`ed. Right at the auto-handover trigger.
- `git ls-remote` to both remotes returned in <5s at investigation time — stall is intermittent, not permanent network failure.
- Reproducer: `git remote add deadremote https://192.0.2.1/x.git && fw handover --commit` should hang for minutes-to-hours with current code.

## Impact

- Sessions freeze for hours, silently consuming time and burning the 5-minute prompt cache TTL.
- No user-visible error — looks like Claude Code is just thinking.
- Masquerades as other issues (model slowness, Claude Code bug, network issue) — wastes investigation time.
- Gets worse as context fills because the bug is armed only at critical level — the busier the session, the more likely to trip.

## Mitigation (immediate)

Users/operators can apply these today without code changes:

1. Set focus to a real task so `check-active-task` stops blocking Write/Edit:
   ```
   cd /opt/999-Agentic-Engineering-Framework && bin/fw work-on T-XXX
   ```
2. If `onedev` is known to be flaky, temporarily remove it: `git remote remove onedev` — restore after fix.
3. Archive huge JSONLs out of `~/.claude/projects/-opt-999-Agentic-Engineering-Framework/` to speed budget-gate.
4. Set git repo-level transport timeouts as belt-and-braces:
   ```
   git config http.lowSpeedLimit 1000
   git config http.lowSpeedTime 10
   ```

## Fix (code change, tracked in T-1277)

1. Wrap every `git push` in `handover.sh:759` with `timeout "${FW_HANDOVER_PUSH_TIMEOUT:-15}" ...`.
2. Add `FW_HANDOVER_PUSH_TIMEOUT` to CLAUDE.md configuration table and `lib/config.sh` defaults.
3. Also bound the auto-handover invocation in `checkpoint.sh:162` with an outer `timeout` — defence in depth.
4. Bats unit test that simulates an unreachable remote and asserts bounded completion.

## Related

- T-1277 — build task for the fix
- T-136 — original auto-handover at critical (introduced the hook trigger)
- T-1144 — "prevent unpushed commit accumulation" — added the push loop this bug lives in
- T-1274 (active) — memory writes blocked by onboarding gate (different bug, similar class: hooks blocking in surprising ways)

## Next actions

- [ ] Framework: pick up `T-1277` into episodic memory
- [ ] Agent implementing fix: write reproducer first, then patch, then bats test
- [ ] After fix ships: delete this observation file or move to `.context/working/observations/processed/`
