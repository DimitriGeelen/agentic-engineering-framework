---
id: T-583
name: "Inception: Background health check — periodic silent-failure detection for hooks, tasks, focus"
description: >
  Framework is blind between explicit fw doctor / fw audit runs. Hooks can break silently mid-session and nobody notices. Real example: check-project-boundary.sh built but not in settings.json — protection appears to exist but never fires. OpenClaw runs health monitor every 5min detecting stale sockets, stuck sessions, half-dead connections. Investigate: piggyback on PostToolUse checkpoint.sh — every Nth tool call (20?), run quick sanity check: (1) Do all hooks in settings.json resolve to executable scripts? (2) Does focus.yaml parse and point to real task in .tasks/active/? (3) Any task files with broken YAML frontmatter? (4) Is session ID still valid? Cost ~100ms every 20 calls. Connects to T-582 (crash recovery is a health check) and T-578 (loop detection is monitoring). Research source: /opt/openclaw-evaluation/.context/working/round2-T-019.md (full observability analysis). OpenClaw source: src/channels/channel-health.ts (5min background monitor), src/gateway/readiness.ts (aggregated health probe). Related framework: agents/context/checkpoint.sh (existing PostToolUse hook — integration point), agents/context/budget-gate.sh (PreToolUse pattern), bin/fw doctor (existing on-demand diagnostics to reuse).

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:21:51Z
last_update: 2026-03-28T09:32:01Z
date_finished: 2026-03-28T09:32:01Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-583: Inception: Background health check — periodic silent-failure detection for hooks, tasks, focus

## Problem Statement

Framework is blind between `fw doctor`/`fw audit` runs. Hooks can break silently mid-session. See `docs/reports/T-583-background-health-check.md`.

## Assumptions

1. Mid-session hook breakage is a real problem (validated: check-project-boundary.sh incident)
2. Lightweight probe is feasible (<200ms every 20 calls) — validated
3. checkpoint.sh is the natural integration point — validated

## Exploration Plan

1. Inventory existing health mechanisms — DONE (5 mechanisms, gap identified)
2. Review checkpoint.sh integration point — DONE
3. Design quick probe (5 checks, <200ms target) — DONE
4. Evaluate 3 options (checkpoint counter, separate hook, cron) — DONE

## Technical Constraints

- checkpoint.sh already runs on every tool call — adding checks must be fast
- Cron runs outside Claude Code process — can't emit warnings to agent

## Scope Fence

**IN:** Counter-based probe in checkpoint.sh, health status file, agent warnings
**OUT:** Full audit in-session, network health, Watchtower health indicator (later)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Evidence of mid-session hook breakage (validated)
- Probe feasible at <200ms overhead (validated)

**NO-GO if:**
- Probe too slow for PostToolUse hook
- No evidence of silent failures mid-session

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T19:16:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:32:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-435fbf78
- **Timestamp:** 2026-06-02T15:03:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
