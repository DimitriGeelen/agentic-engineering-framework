---
id: T-1388
name: "Watchtower /inception/T-XXX page is one-shot — no revoke/re-decide affordance after decision recorded"
description: >
  Inception: Watchtower /inception/T-XXX page is one-shot — no revoke/re-decide affordance after decision recorded

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-22T21:35:53Z
last_update: 2026-04-22T21:37:45Z
date_finished: null
---

# T-1388: Watchtower /inception/T-XXX page is one-shot — no revoke/re-decide affordance after decision recorded

**Research artifact:** [docs/reports/T-1388-watchtower-inception-no-redecide.md](../../docs/reports/T-1388-watchtower-inception-no-redecide.md) — full root-cause, code evidence, assumptions, exploration plan, dialogue log.

## Problem Statement

Once `fw inception decide` records a decision on a task, Watchtower's `/inception/T-XXX` page shows only the Decision Record (read-only). The form to record a decision disappears. There is no "revoke" or "re-decide" affordance. If the initial decision is wrong or superseded by new scoping, the only recovery path today is manually editing the task markdown to strip the `## Decisions` block so the form re-renders — bypassing the inception-decide pipeline (rationale capture, timestamp, Updates log).

**Who:** human reviewers + agents recording corrected decisions.
**Why now:** hit this during G-056 work on T-1270 — had to strip `## Decisions` by hand. This is the agent-workaround-worse-than-bug pattern (G-019): the unsafe manual edit bypasses audit. Flagged as high-priority bugfix.

## Assumptions

- A1: Humans actually want to re-decide occasionally (vs. create a new follow-up task)
- A2: The current one-shot form is deliberate constraint, not oversight (commit archaeology will tell)
- A3: "Revoke" and "re-decide" are different UX (revoke → pending; re-decide → overwrite with new rationale)
- A4: Backend `record_decision` route is already idempotent — re-exposing the form may be enough

## Exploration Plan

- Spike A — Count active+completed inceptions with multiple decision entries in `## Updates` (tests A1 quantitatively)
- Spike B — `git log -p web/templates/inception_detail.html` for the decision block (tests A2)
- Spike C — Confirm `lib/inception.sh do_inception_decide` can overwrite idempotently (tests A4)
- Spike D — UX sketch: D1 (re-open button) vs D2 (new-decision form with confirm field)

## Technical Constraints

- Must preserve audit trail: each decision entry visible in `## Updates`
- Must not silently overwrite the canonical `## Decision` block without Update entry
- Agent-invocation guard (T-1259) must still block programmatic abuse: `--from-watchtower` flag is the sanctioned path for Watchtower re-decide
- CSRF token on any new POST route

## Scope Fence

**IN:**
- UI affordance to record a superseding decision
- Backend route(s) to accept revoke or re-decide with audit entry
- Invariant test: re-decided tasks have both decision entries in Updates log

**OUT:**
- Data model rewrite (single-canonical `## Decision` stays, history stays in `## Updates`)
- "Decision history" visualisation (follow-up if justified)
- Multi-user authorization flows

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

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

### 2026-04-22T21:37:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
