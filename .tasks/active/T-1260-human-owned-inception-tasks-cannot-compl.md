---
id: T-1260
name: "Human-owned inception tasks cannot complete — 5 layered root causes (sovereignty, dispatch, template drift, recommendation gate, tier0 hash)"
description: >
  Inception: Human-owned inception tasks cannot complete — 5 layered root causes (sovereignty, dispatch, template drift, recommendation gate, tier0 hash)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-14T23:01:08Z
last_update: 2026-04-14T23:02:48Z
date_finished: null
---

# T-1260: Human-owned inception tasks cannot complete — 5 layered root causes (sovereignty, dispatch, template drift, recommendation gate, tier0 hash)

## Problem Statement

Cross-session report (high-priority, 2026-04-15): inception tasks with
`owner: human` cannot be completed through any available pathway. Decision is
recorded (multiple times in some cases) but status stays stuck at
`started-work`. Observed layered failure across five distinct surfaces:

| Path tried | Result |
|-----------|--------|
| `fw inception decide T-002 go` (CLI, agent-run) | Tier 0 block — requires human approval |
| `fw tier0 approve` + retry (CLI) | Retry hits Tier 0 again — hash drift or approval consumed |
| Watchtower /inception/T-XXX → click GO | Decision block written. Status does NOT transition. Error truncated to "Task Update ... F" |
| `fw task update T-XXX --status work-completed` (agent) | Sovereignty gate R-033 blocks: "Cannot complete human-owned task" |
| `fw task review T-XXX` | Dispatch script missing: `/tmp/tl-dispatch/fabric-purpose-fill/run.sh` |

Contrast: T-006 (also `owner: human`) transitioned cleanly because the decide
was run directly from the human's terminal (no agent identity, no Watchtower).

**Result:** decision recorded repeatedly (T-002 has 3+ duplicated inception-decision
blocks from multiple Watchtower clicks), status never advances.

## Assumptions

- A1: The five root causes are independent but compound — fixing any one alone leaves task completion still broken
- A2: Watchtower backend runs with agent-identity (not human-identity via session auth)
- A3: The dispatch script missing is the same class as T-007 (not-yet-diagnosed dispatch path bug)
- A4: Template drift is finite — only older inception tasks are missing `## Decision` / `## Recommendation` headers
- A5: Tier 0 hash drift is reproducible given two identical-looking invocations

## Exploration Plan

- **Spike A (20min) — Sovereignty gate asymmetry:** Trace how Watchtower `/inception/T-XXX/decide` POST reaches update-task.sh. Is there any identity signal that could bypass R-033 when the request comes from Watchtower's web session? Examine `web/blueprints/inception.py`.
- **Spike B (15min) — Dispatch script materialization:** Find every `/tmp/tl-dispatch/*/run.sh` reference in the codebase. What's supposed to write these scripts? Why did `fabric-purpose-fill/run.sh` not materialize? Link to T-007.
- **Spike C (10min) — Template completeness:** Audit `.tasks/templates/inception.md` and all template variants. Confirm every new inception has `## Decision`, `## Recommendation`, `## Updates` sections. Test: `fw task create --type inception` and grep output.
- **Spike D (5min) — Recommendation gate ordering:** The `## Recommendation required` gate fires on decide. Is the decide flow calling the gate before the recommendation-writer (Watchtower) has finished writing?
- **Spike E (20min) — Tier 0 hash drift:** Look at `lib/tier0.sh` (or equivalent) to understand hash normalisation. Test: run same command twice, compare hashes. If drift is present, identify the non-deterministic input (whitespace, timestamps, env var).
- **Spike F (10min) — Workaround validation:** Confirm the "human runs decide from own terminal" workaround actually works (proven for T-006). Document it as a stopgap until the structural fixes ship.

## Technical Constraints

- Watchtower HTTP backend is Flask (web/app.py), Python 3.12 — identity propagation via session cookie would require flask-login or equivalent wiring
- Tier 0 approve machinery: `.context/working/.tier0-approved-*` hash files (transient)
- R-033 rule lives in update-task.sh:~200 (sovereignty gate)
- Dispatch scripts under `/tmp/tl-dispatch/` — Claude TermLink integration surface, per-session ephemeral
- Data loss risk: duplicate decision blocks mean if we auto-dedupe we might lose the human's latest choice

## Scope Fence

**IN:**
- Why each of the 5 root causes fires
- Minimal intervention to unblock *immediate* human-inception-completion
- Recommendation on which root causes get own bugfix tasks vs. bundled

**OUT:**
- Rewriting the inception workflow end-to-end (would be a separate design task)
- Tier 0 approval redesign (R-033 specifically in scope, Tier 0 generally out)
- Watchtower auth overhaul (session cookies, flask-login adoption — noted as follow-up)

## Acceptance Criteria

### Agent
- [ ] Spike A complete: sovereignty gate asymmetry traced; finding documented
- [ ] Spike B complete: dispatch script origin identified; linked to T-007
- [ ] Spike C complete: template completeness audit done; gaps listed
- [ ] Spike D complete: recommendation gate ordering diagnosed
- [ ] Spike E complete: Tier 0 hash drift reproduced or ruled out
- [ ] Spike F complete: human-terminal workaround verified + documented
- [ ] Research artifact written to `docs/reports/T-1260-human-inception-completion.md`
- [ ] Recommendation with GO/NO-GO/DEFER + concrete bugfix task list for build follow-up

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

### 2026-04-14T23:02:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
