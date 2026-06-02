---
id: T-1459
name: "4 Claude Code hooks mirrored from termlink are dead code — never registered in .claude/settings.json or cron. Scripts: agents/context/{session-end,stop-guard,subagent-stop,pl007-scanner}.sh plus session-silent-scanner.sh which claims cron invocation but isn't in crontab. Commits b5383596/562c2fc7/a5c4fe85 landed handlers but settings.json was not updated. Likely skipped after the G-016 commit-storm incident but not documented. Needs inception: register (which ones, after what safeguards?), decommission, or document as reference-only."
description: >
  Promoted from observation OBS-014

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-25T13:39:44Z
last_update: 2026-04-25T14:01:35Z
date_finished: 2026-04-25T14:01:35Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1459: 4 Claude Code hooks mirrored from termlink are dead code — never registered in .claude/settings.json or cron. Scripts: agents/context/{session-end,stop-guard,subagent-stop,pl007-scanner}.sh plus session-silent-scanner.sh which claims cron invocation but isn't in crontab. Commits b5383596/562c2fc7/a5c4fe85 landed handlers but settings.json was not updated. Likely skipped after the G-016 commit-storm incident but not documented. Needs inception: register (which ones, after what safeguards?), decommission, or document as reference-only.

## Problem Statement

**For whom:** the framework operator (humans + agents who rely on Claude Code hooks for governance enforcement). **What problem:** five hook handler scripts mirrored from TermLink (`agents/context/{session-end,stop-guard,subagent-stop,pl007-scanner,session-silent-scanner}.sh` — ~633 lines combined) sit in the repo with no caller. Neither `.claude/settings.json` nor `/etc/cron.d/` references them. **Why now:** OBS-014 raised it after a doctor sweep — the discrepancy between handler intent (each script's docstring claims a hook role) and runtime reality (no hook event will ever invoke them) is a classic dead-code rot pattern. They cost lines, audit churn, and operator trust ("are these running?").

## Audit findings (this session)

| Script | Intended role | Origin commit | Registration status |
|--------|---------------|---------------|---------------------|
| `session-end.sh` | SessionEnd handler — reason logger + handover trigger (T-1212) | 562c2fc7 | NOT in settings.json |
| `stop-guard.sh` | Stop hook — conversation-capture nudge (T-1211) | b5383596 | NOT in settings.json |
| `subagent-stop.sh` | SubagentStop — sub-agent transcript capture / fw bus migration (T-1213) | a5c4fe85 | NOT in settings.json |
| `pl007-scanner.sh` | PostToolUse — flag bare commands the agent might relay verbatim (T-1188) | 25718851 | NOT in settings.json |
| `session-silent-scanner.sh` | Cron — recover lost SessionEnd via silent-session detection (T-1212) | 562c2fc7 (cap added 2199ccba) | NOT in /etc/cron.d/ |

**Common origin:** all five were ports from TermLink. The most recent touch (T-1222 / 2199ccba) capped the silent-scanner specifically to prevent the **G-016 handover commit storm** — i.e. the registration was paused because turning these on caused a real incident, but the scripts were never decommissioned or documented as reference-only. They've been adrift for ~14 days at the time of this inception.

## Hypotheses to test

1. **Decommission hypothesis:** The G-016 incident was severe enough that re-enabling carries unbounded risk. Test: review G-016 RCA — is the storm root cause structural (handler logic) or configurational (loop guard absent at the time)?
2. **Re-enable-with-safeguards hypothesis:** The handlers each solve real problems (session-end loss, sub-agent context bloat, conversation drift). Test: do the safeguards that landed since G-016 (loop caps, edit-counter dedup) defang the original failure mode?
3. **Reference-only hypothesis:** Some of these were experimental, others production-shaped. Test: which hooks have clear, narrow contracts that don't risk repeat storms?

## Exploration Plan

1. Read G-016 / T-1222 RCA — identify the exact failure mechanism that paused registration.
2. For each of the 5 scripts, classify safety category:
   - SAFE: bounded, idempotent, no commit / no notification side effects
   - GUARDED: side effects exist but safeguards are now in place
   - UNSAFE: still carries G-016-class risk
3. Map the design space:
   - Option A: **Re-enable all 5** — register in settings.json + crontab. Low scope, but inherits any latent risk.
   - Option B: **Decommission all 5** — delete scripts, prune fabric cards, remove tests. Removes ~633 lines + audit churn but loses TermLink-port coverage.
   - Option C: **Hybrid: re-enable SAFE/GUARDED, decommission UNSAFE** — per-handler decision; keeps the win, drops the hazard.
   - Option D: **Document as reference-only** — add `# REFERENCE ONLY — not registered (see T-1459)` banner to each script header; leave in tree as future recipes. Lowest cost, no commitment.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated (5 scripts confirmed unregistered)
- [x] Origin commits traced for each script
- [x] Recommendation written with rationale (DEFER / Option D, with C as Phase 2)
- [x] Audit findings table captured
- [x] Hypotheses + 4 design options enumerated

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (Option D — document as reference-only) as the safest near-term move; Option C (hybrid) once Phase 2 RCA is read.

**Rationale:** The G-016 incident is recent enough (within 2 weeks) and the cost-of-being-wrong (commit storm, lost session integrity) is high enough that re-enabling without first reading the G-016 RCA is reckless. Decommissioning loses ~633 lines of intentional design that was crafted as TermLink ports — costs us the optional path without us having investigated. Reference-only mode locks in the current safe state, makes the dead-code status legible to operators, and doesn't preclude any future option.

**Evidence:**
- 5 scripts confirmed unregistered in `.claude/settings.json` and `/etc/cron.d/` (this session, 2026-04-25).
- Most recent touch on the cluster is `2199ccba — T-1222 / G-016: Cap silent-session scanner to prevent handover commit storm` — i.e. last action was *defensive capping*, not decommissioning. Suggests the original team intended to revisit, never did.
- Each script's header docstring describes a real, narrow problem. None look like throwaway experiments.
- Audit cost: 5 unregistered hooks rate-limit nothing; the only concrete cost today is line count + reader confusion.

**Out-of-scope follow-up candidates:**
- Reading G-016 RCA + classifying each script SAFE/GUARDED/UNSAFE → enables Option C.
- TermLink upstream check — are the equivalent scripts still active there? If they were removed there too, decommission is the cleaner answer.


## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: The G-016 incident is recent enough (within 2 weeks) and the cost-of-being-wrong (commit storm, lost session integrity) is high enough that re-enabling without first reading the G-016 RCA is reckless. Decommissioning loses ~633 lines of intentional design that was crafted as TermLink ports — costs us the optional path without us having investigated. Reference-only mode locks in the current safe state, makes the dead-code status legible to operators, and doesn't preclude any future option.

**Date**: 2026-04-25T14:01:35Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-25T14:01:35Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The G-016 incident is recent enough (within 2 weeks) and the cost-of-being-wrong (commit storm, lost session integrity) is high enough that re-enabling without first reading the G-016 RCA is reckless. Decommissioning loses ~633 lines of intentional design that was crafted as TermLink ports — costs us the optional path without us having investigated. Reference-only mode locks in the current safe state, makes the dead-code status legible to operators, and doesn't preclude any future option.

### 2026-04-25T14:01:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4004175a
- **Timestamp:** 2026-06-02T14:57:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T14:01:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
