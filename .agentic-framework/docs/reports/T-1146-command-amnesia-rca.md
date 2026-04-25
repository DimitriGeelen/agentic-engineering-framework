# T-1146 — Agent Command Amnesia RCA

**Source:** P-020 pickup from 010-termlink (T-972)
**Severity:** CRITICAL — framework scripts ARE the violation source
**Date:** 2026-04-12

## Problem

The agent violated PL-007 (never output bare commands) within 3 minutes of BUILDING PL-007. Five fixes in one session all failed. The root cause is that framework gate scripts themselves output bare commands as error messages, which the agent relays verbatim to the human.

## Three Root Causes

### RC-1: Framework gate scripts output bare commands

Gate scripts (hooks, update-task, audit) print messages like "run this command: `fw inception decide T-XXX go`" when blocking an action. The agent relays these to the human, violating PL-007 (always use `fw task review`, never dump CLI commands).

**Audit of bare command output sites (2026-04-12 scan):**

| File | Line(s) | Pattern | Severity |
|------|---------|---------|----------|
| `agents/context/check-tier0.sh` | 147 | "ask the human to run: fw inception decide..." | HIGH — tier0 block is the primary gate |
| `agents/context/check-active-task.sh` | 131,135,168-169,198,201,217-218,238,249-250,296,299,344 | Multiple "fw work-on", "fw task create", "fw context init" | MEDIUM — onboarding/guidance |
| `agents/context/block-task-tools.sh` | 7-8 | "Use 'bin/fw work-on...'" | LOW — redirect message |
| `agents/context/check-agent-dispatch.sh` | 96,102 | "fw termlink dispatch", "fw dispatch approve" | MEDIUM — dispatch guidance |
| `agents/task-create/update-task.sh` | 177,452,643,710,841,860 | "fw task review", "fw task update", "fw healing diagnose" | HIGH — most common path |
| `agents/audit/audit.sh` | 140,229,234,254,256,261,2929 | "fw audit schedule install", "fw context add-learning" | LOW — informational |
| `agents/context/lib/init.sh` | 113,120,123,126,152,181,203 | "fw work-on", "fw help", "fw fabric scan" | LOW — session init |

**Total: ~40 bare command output sites across 7 files.**

### RC-2: No governance over agent text output

Claude Code has no `PreTextOutput` or `PostMessage` hook. The agent's prose output is completely ungoverned — there's no way to intercept and rewrite bare commands into Watchtower URLs. This is a platform limitation (Claude Code hooks only cover tool use).

**Assessment:** Not fixable at framework level. Would require Claude Code platform change. Alternative: make gate scripts emit Watchtower-friendly output so there's nothing to rewrite.

### RC-3: No shared Watchtower URL helper

Port 3000 is hardcoded in 4+ scripts. `fw task review` is the canonical command that does port detection + identity verification + URL emission. But gate scripts don't call it — they print bare `fw` commands.

**Assessment:** A shared `lib/watchtower.sh` helper could encapsulate URL generation with port detection, so any script that needs to direct the human to Watchtower uses the helper instead of hardcoding.

## What's Already Fixed

- **T-1106:** `fw task review` now does identity endpoint check before emitting URL
- **T-1141:** PL-007 codified in CLAUDE.md — "always use fw task review, never dump CLI commands"
- **T-1154:** Watchtower port detection upstreamed to shared helper in `bin/watchtower.sh`

## What Remains

1. **RC-1 (40 sites):** Gate scripts still output bare commands. Need refactoring to:
   - Output Watchtower URLs instead of CLI commands where applicable
   - Or output "review in Watchtower" with the URL, not "run this command"
   - Priority: HIGH sites (check-tier0.sh, update-task.sh) first

2. **RC-2 (ungoverned prose):** Not fixable without platform change. Mitigation: fix RC-1 so there's nothing to relay.

3. **RC-3 (shared helper):** Partially fixed by T-1154. Need to:
   - Audit remaining hardcoded `:3000` references
   - Ensure `bin/watchtower.sh` helper is used consistently

## Recommendation

**GO — targeted refactoring of HIGH-severity gate script outputs.**

Focus on the ~10 HIGH-severity sites in `check-tier0.sh` and `update-task.sh` that produce the most visible bare commands. These are the messages agents relay most often. The MEDIUM and LOW sites are informational and less likely to cause PL-007 violations.

**Proposed build tasks (if GO):**
1. Refactor `check-tier0.sh` block message to emit Watchtower approval URL
2. Refactor `update-task.sh` output to use `fw task review` pattern
3. Audit and fix remaining hardcoded `:3000` references

**Risk if NO-GO:** Agent continues relaying bare commands from gate scripts. PL-007 violations recur. Human correction cycle continues.
