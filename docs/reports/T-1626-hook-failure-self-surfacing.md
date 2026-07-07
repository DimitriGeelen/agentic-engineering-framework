# T-1626 — Hook failures must self-surface (non-blocking ≠ invisible)

> **Inception research artifact** (backfilled T-2515 from the T-1626 task body — the
> research was captured in-task at decision time; this extracts it to the canonical
> `docs/reports/` home per C-001). Source: `.tasks/completed/T-1626-*.md`.
> **Decision recorded: GO** (2026-04-30).

## Research question

Should the framework treat "non-blocking" hook failures as a first-class signal —
i.e. record, threshold, and surface them — rather than letting them flow past as
invisible wallpaper?

## Problem statement

A consumer Claude Code session (`/root/ring20-dashboard/...`) repeatedly fired
`PostToolUse:Edit` / `PreToolUse:Bash` / `PostToolUse:Read` hooks that all failed
with `/bin/sh: 1: .agentic-framework/bin/fw: not found`. The agent had `cd`-ed into
a subdirectory; the hook command in `.claude/settings.json` is the **CWD-relative**
path `.agentic-framework/bin/fw`, which resolves only when CWD is the consumer root.

Because Claude Code labels these "non-blocking status code":
1. The tool calls succeeded.
2. The framework recorded **zero** signal of breakage — no telemetry counter, no
   `concerns.yaml` entry, `fw doctor` would have passed.
3. The agent worked through dozens of these errors as visual wallpaper.
4. Only the human watching the chat noticed.

**Root cause = framework blindness, not the broken hook.** The enforcement loop is
*structural problem → hook fires → action blocked / telemetry recorded → audit
notices → gap registered → fix ships*. For non-blocking hook failures the loop snaps
at step 3 — structurally identical to G-019 (symptom-level OK while root cause
persists).

## Assumptions (from task body)

- **A1:** Hook commands use CWD-relative `.agentic-framework/bin/fw` paths today.
- **A2:** Non-blocking hook failures write nothing to `.context/working/` or `concerns.yaml` — zero structural footprint.
- **A3:** `fw doctor` does not exercise hooks from a non-root CWD.
- **A4:** `fw upgrade` has the consumer's absolute path at install time but doesn't bake it in.
- **A5:** Claude Code hooks run with CWD = the agent's current shell CWD, not project root.
- **A6:** Running each registered hook once at SessionStart for a self-test costs <100ms total.

## Exploration plan (3 spikes, ≤90 min)

1. **Reproduce + characterise** (≤20m): `cd` into a consumer subdir, run a hook directly, confirm the not-found error and the absence of any telemetry footprint.
2. **Surface design** (≤30m): decide where the signal lives (counter file, concerns entry, doctor check).
3. **Fix-path shape** (≤40m): scope the CWD-invariant resolution + telemetry + escalation.

## Decision — GO

**Rationale:** structural blindness, not a tactical bug. A framework that doesn't
notice its own broken plumbing is structurally identical to G-019. The fix path is
bounded (4 small build tasks, each <2h), reversible (each change is a settings.json
edit + a counter file), and immediately testable from any subdir.

**Evidence:**
- Live transcript (2026-04-30, ring20-dashboard) — dozens of non-blocking hook failures, all invisible to telemetry.
- `~/.local/bin/fw` already does walk-up resolution for the user-facing CLI; extending to hooks is symmetric, low-risk.
- G-011 (PostToolUse advisory-only) and G-019 (no self-escalation) are the parent gaps.
- Cross-consumer reach: same fragile pattern in every `fw upgrade`-initialised project (gap homes here per T-1333).

**Build carve-out (ordered by criticality):**
1. **B-1 — CWD-invariant hook resolution.** Shim / inline `cd $(git rev-parse --show-toplevel)` / install-time absolute-path baking; bats-test from `/tmp` and a deep subdir.
2. **B-2 — Hook telemetry.** `.hook-counter` + `.hook-failure-counter` per-hook fire/fail counts (<5ms/fire).
3. **B-3 — Threshold escalation + Watchtower `/hooks`.** N failures in M minutes → auto-register a gap; doctor exercises every hook from `/tmp`.
4. **B-4 — SessionStart self-test.** Invoke each hook once with safe stdin; warn on command-not-found / non-zero.

**DEFER** would be acceptable only if a higher-priority structural blindness were being
fixed first — noting that delay means consumers keep shipping silently broken hooks
until a human notices or a Tier-0 gate is the one that breaks (at which point it is a
security incident, not "non-blocking"). **NO-GO** would require evidence that
hook-failure blindness is acceptable risk; no such evidence exists.
