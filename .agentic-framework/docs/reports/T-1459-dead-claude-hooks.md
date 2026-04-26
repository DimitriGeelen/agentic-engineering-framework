# T-1459 — Dead Claude Code Hook Scripts

**Type:** Inception
**Date:** 2026-04-25
**Decision:** DEFER → reference-only (Option D)
**Source task:** `.tasks/completed/T-1459-4-claude-code-hooks-mirrored-from-termli.md`

## Problem Statement

**For whom:** the framework operator (humans + agents who rely on Claude Code hooks for governance enforcement).

**What problem:** five hook handler scripts mirrored from TermLink (`agents/context/{session-end,stop-guard,subagent-stop,pl007-scanner,session-silent-scanner}.sh` — ~633 lines combined) sit in the repo with no caller. Neither `.claude/settings.json` nor `/etc/cron.d/` references them.

**Why now:** OBS-014 raised it after a doctor sweep — the discrepancy between handler intent (each script's docstring claims a hook role) and runtime reality (no hook event will ever invoke them) is a classic dead-code rot pattern. They cost lines, audit churn, and operator trust ("are these running?").

## Options Considered

| Option | Description | Risk |
|---|---|---|
| A — register | Re-register all 5 in settings.json/cron | High (G-016 commit storm risk) |
| B — decommission | Delete all 5 scripts | Loses ~633 lines of intentional design without RCA |
| C — hybrid | Register only G-016-safe ones; decommission the rest | Requires reading G-016 RCA first |
| D — reference-only | Brand each script `# REFERENCE ONLY — not registered` | Lock-in current safe state, defer real choice |

## Recommendation

**DEFER with Option D (reference-only)** as the safest near-term move; revisit Option C once Phase 2 G-016 RCA has been read.

**Rationale:** The G-016 incident is recent (within 2 weeks) and the cost-of-being-wrong (commit storm, lost session integrity) is high. Re-enabling without first reading the G-016 RCA is reckless. Decommissioning loses ~633 lines of intentional design — costs us the optional path. Reference-only mode locks in the current safe state, makes the dead-code status legible to operators, and doesn't preclude any future option.

**Evidence:**
- 5 scripts confirmed unregistered in `.claude/settings.json` and `/etc/cron.d/` (2026-04-25 sweep)
- Most recent touch: `2199ccba — T-1222 / G-016: Cap silent-session scanner to prevent handover commit storm` — last action was *defensive capping*, not decommissioning. Original team intended to revisit, never did.
- Each script's header docstring describes a real, narrow problem. None look like throwaway experiments.
- Audit cost today: line count + reader confusion only.

**Out-of-scope follow-ups:**
- Reading G-016 RCA + classifying each script SAFE/GUARDED/UNSAFE → enables Option C
- TermLink upstream check — are equivalents still active there?

## Outcome

Build task T-1463 added `# REFERENCE ONLY — not registered in .claude/settings.json (see T-1459)` banner to all 5 scripts (closed 2026-04-25).
