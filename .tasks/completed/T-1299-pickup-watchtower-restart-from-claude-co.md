---
id: T-1299
name: "Pickup: Watchtower restart from Claude Code session requires setsid + Jinja cache requires full process kill (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1117. Type: learning.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, learning]
components: []
related_tasks: []
created: 2026-04-18T15:21:47Z
last_update: 2026-04-19T08:57:23Z
date_finished: 2026-04-19T08:57:23Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1299: Pickup: Watchtower restart from Claude Code session requires setsid + Jinja cache requires full process kill (from termlink)

## Problem Statement

Termlink captured two restart-semantics learnings during T-1117..T-1121 UI work:
(1) restarting Watchtower from a Claude Code `Bash` invocation requires `setsid` — plain `nohup ... &` or `& disown` don't survive, and the symptom is a silent death right after "started" is echoed. (2) Flask production-mode caches compiled Jinja2 templates in memory; `find __pycache__ -delete` is insufficient — only a full process kill picks up template edits.

Proposed codification: `fw serve` (or a wrapper) detects `$CLAUDECODE=1` and prepends `setsid`; always kills any process bound to the target port before launching; documents the Jinja cache behavior. Full triage: `docs/reports/T-1299-watchtower-setsid-jinja.md`.

## Assumptions

1. The setsid learning is already captured in framework memory — TESTED FALSE (grep of learnings.yaml + CLAUDE.md shows no mention)
2. The Jinja cache learning is partially captured — TESTED TRUE (agent memory MEMORY.md has it, but not in `.context/project/learnings.yaml`)
3. Codification is bounded to one file (`lib/serve.sh` or similar) + a bats test — TESTED TRUE

## Exploration Plan

10-min time-box (completed):
- Grep for setsid + Jinja in `.context/project/`, CLAUDE.md, agent memory — DONE
- Confirm `fw serve` exists and is the natural integration point — DONE
- Evaluate reversibility/testability — DONE (feature-flag-able via env, mock-able in bats)

## Technical Constraints

- Claude Code's Bash tool runs commands in a session whose children inherit a controlling terminal; `setsid` decouples the child so it survives tool-call completion.
- Flask's Jinja2 environment compiles templates lazily and caches by name; cache is in `Environment.cache` (dict), cleared only by new-process boot.

## Scope Fence

**IN:** codify setsid-on-CLAUDECODE + pre-port-kill in `fw serve`; capture both learnings explicitly; document Jinja cache in docs/watchtower.md.
**OUT:** broader refactor of Watchtower startup; hot-reload template infra; setsid for non-Watchtower processes.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (termlink T-1117 pickup with concrete operator pain: 4 failed restart attempts)
- [x] Assumptions tested (1 false, 1 partial, 1 true)
- [x] Recommendation written with rationale (GO — build sibling deferred to next session)

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

**Recommendation:** GO

**Rationale:** Concrete operator pain (4 failed restart attempts on termlink, real diagnostic time lost). Both learnings are field-discovered and not yet codified at the framework level. The fix is bounded — extend `fw serve` with CLAUDECODE-aware setsid + pre-port-kill. Reversible, testable via bats. Build is well-scoped and suitable for a single session.

**Evidence:**
- Pickup payload names 4 failed restart attempts + symptom (silent death after "started" echo) — concrete evidence of cost
- Grep confirms `setsid` is not in `.context/project/learnings.yaml` or CLAUDE.md — not codified
- `fw serve` exists as the natural integration point; scope fits in <50 lines
- Agent memory has partial Jinja learning; promoting to framework learnings + docs closes the gap
- Full triage: `docs/reports/T-1299-watchtower-setsid-jinja.md`

**Build plan (deferred to next session as T-1326 or similar):**
1. Extend `fw serve` / `lib/serve.sh` — if `${CLAUDECODE:-0}` = 1, prepend setsid
2. Pre-launch: kill process bound to target port (`fuser -k` or portable equivalent), confirm free
3. Post-launch: poll `/health` up to 10s; exit non-zero if not ready
4. L-??? + L-??? captured: setsid requirement + Jinja in-memory cache
5. `tests/unit/watchtower_serve.bats` — fake CLAUDECODE, assert setsid in command; port-kill path
6. `docs/watchtower.md`: "Restart from Claude Code sessions" section

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

**Rationale**: Recommendation: GO

Rationale: Concrete operator pain (4 failed restart attempts on termlink, real diagnostic time lost). Both learnings are field-discovered and not yet codified at the framework level. The fix is bounded — extend `fw serve` with CLAUDECODE-aware setsid + pre-port-kill. Reversible, testable via bats. Build is well-scoped and suitable for a single session.

Evidence:
- Pickup payload names 4 failed restart attempts + symptom (silent death after "started" echo) — concrete evidence of cost
- Grep confirms `setsid` is not in `.context/project/learnings.yaml` or CLAUDE.md — not codified
- `fw serve` exists as the natural integration point; scope fits in <50 lines
- Agent memory has partial Jinja learning; promoting to framework learnings + docs closes the gap
- Full triage: `docs/reports/T-1299-watchtower-setsid-jinja.md`

Build plan (deferred to next session as T-1326 or similar):
1. Extend `fw serve` / `lib/serve.sh` — if `${CLAUDECODE:-0}` = 1, prepend setsid
2. Pre-launch: kill process bound to target port (`fuser -k` or portable equivalent), confirm free
3. Post-launch: poll `/health` up to 10s; exit non-zero if not ready
4. L-??? + L-??? captured: setsid requirement + Jinja in-memory cache
5. `tests/unit/watchtower_serve.bats` — fake CLAUDECODE, assert setsid in command; port-kill path
6. `docs/watchtower.md`: "Restart from Claude Code sessions" section

**Date**: 2026-04-19T08:57:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-19T08:18:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-19T08:57:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Concrete operator pain (4 failed restart attempts on termlink, real diagnostic time lost). Both learnings are field-discovered and not yet codified at the framework level. The fix is bounded — extend `fw serve` with CLAUDECODE-aware setsid + pre-port-kill. Reversible, testable via bats. Build is well-scoped and suitable for a single session.

Evidence:
- Pickup payload names 4 failed restart attempts + symptom (silent death after "started" echo) — concrete evidence of cost
- Grep confirms `setsid` is not in `.context/project/learnings.yaml` or CLAUDE.md — not codified
- `fw serve` exists as the natural integration point; scope fits in <50 lines
- Agent memory has partial Jinja learning; promoting to framework learnings + docs closes the gap
- Full triage: `docs/reports/T-1299-watchtower-setsid-jinja.md`

Build plan (deferred to next session as T-1326 or similar):
1. Extend `fw serve` / `lib/serve.sh` — if `${CLAUDECODE:-0}` = 1, prepend setsid
2. Pre-launch: kill process bound to target port (`fuser -k` or portable equivalent), confirm free
3. Post-launch: poll `/health` up to 10s; exit non-zero if not ready
4. L-??? + L-??? captured: setsid requirement + Jinja in-memory cache
5. `tests/unit/watchtower_serve.bats` — fake CLAUDECODE, assert setsid in command; port-kill path
6. `docs/watchtower.md`: "Restart from Claude Code sessions" section

### 2026-04-19T08:57:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-81e0a16f
- **Timestamp:** 2026-06-02T14:56:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
