---
id: T-1213
name: "RCA: Inception decision cards on /approvals show bare radio buttons — no recommendation, no rationale, no context for human decision"
description: >
  Inception: RCA: Inception decision cards on /approvals show bare radio buttons — no recommendation, no rationale, no context for human decision

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T09:09:39Z
last_update: 2026-04-25T18:35:10Z
date_finished: 2026-04-13T09:18:12Z
---

# T-1213: RCA: Inception decision cards on /approvals show bare radio buttons — no recommendation, no rationale, no context for human decision

## Problem Statement

On `/approvals`, inception GO/NO-GO decision cards appear bare — radio buttons + rationale textarea,
but no agent recommendation, research findings, or evidence. The human must read the task file
separately to understand what's recommended and why. Affects ALL projects (framework + consumers).

Two failure modes:
1. **UI gap:** recommendation data IS in the task file but doesn't render visibly
2. **Process gap:** agent sometimes writes `## Recommendation` and sometimes doesn't

## Assumptions

- A1: Template has conditional rendering that hides recommendation when data is missing
- A2: Backend extracts and passes recommendation data correctly
- A3: Some inception tasks lack `## Recommendation` sections entirely (process failure)
- A4: T-1123 filter (skip tasks without recommendation) may not be strict enough

## Exploration Plan

1. Read template + backend data flow for inception cards
2. Test with real data — check which framework cards show recommendations
3. Scan active inception tasks for missing `## Recommendation` sections
4. Identify root cause(s) and propose fix(es)

## Technical Constraints

None — pure Watchtower (Flask + Jinja2) and agent process discipline.

## Scope Fence

**IN:** Fix inception decision card rendering on `/approvals` + structural enforcement for recommendations.
**OUT:** Tier 0 cards, Human AC cards, `/inception/<task_id>` detail page (already rich).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix covers both UI rendering AND process enforcement

**NO-GO if:**
- Issue requires fundamental template engine changes

## Verification

# Research artifact exists
test -f docs/reports/T-1213-inception-approvals-bare-cards-rca.md

## Recommendation

**Recommendation:** GO — 3 bounded fixes addressing both UI and process gaps.

**Rationale:** The root cause has two layers: (1) the template hides the recommendation block entirely when data is missing (`{% if t.recommendation %}`), leaving bare radio buttons; (2) the agent inconsistently writes `## Recommendation` sections — no structural gate enforces this before the task reaches `/approvals`. Both are fixable: template fallback for UI, `fw task review` warning for process.

**Evidence:**
- Framework cards render correctly (3/3 tested with full recommendation + prefill)
- Consumer cards appear bare when `## Recommendation` is absent from task files
- Template line 87: `{% if t.recommendation %}` — hides entire context block
- Backend already extracts Go/No-Go Criteria as rationale_hint fallback, but ONLY for textarea — not for visible display
- User confirmed: "often you do it correct and often you forget" — recurring agent behavioral failure

**Proposed build tasks (2):**
1. Fix template to show fallback context (Go/No-Go Criteria, problem statement, warning) when recommendation is missing
2. Add warning to `fw task review` for inception tasks without substantive `## Recommendation`

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

**Rationale**: Recommendation: GO — 3 bounded fixes addressing both UI and process gaps.

Rationale: The root cause has two layers: (1) the template hides the recommendation block entirely when data is missing (`{% if t.recommendation %}`), leaving bare radio buttons; (2) the agent inconsistently writes `## Recommendation` sections — no structural gate enforces this before the task reaches `/approvals`. Both are fixable: template fallback for UI, `fw task review` warning for process.

Evidence:
- Framework cards render correctly (3/3 tested with full recommendation + prefill)
- Consumer cards appear bare when `## Recommendation` is absent from task files
- Template line 87: `{% if t.recommendation %}` — hides entire context block
- Backend already extracts Go/No-Go Criteria as rationale_hint fallback, but ONLY for textarea — not for visible display
- User confirmed: "often you do it correct and often you forget" — recurring agent behavioral failure

Proposed build tasks (2):
1. Fix template to show fallback context (Go/No-Go Criteria, problem statement, warning) when recommendation is missing
2. Add warning to `fw task review` for inception tasks without substantive `## Recommendation`

**Date**: 2026-04-13T09:18:12Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-13T09:09:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-13T09:18:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — 3 bounded fixes addressing both UI and process gaps.

Rationale: The root cause has two layers: (1) the template hides the recommendation block entirely when data is missing (`{% if t.recommendation %}`), leaving bare radio buttons; (2) the agent inconsistently writes `## Recommendation` sections — no structural gate enforces this before the task reaches `/approvals`. Both are fixable: template fallback for UI, `fw task review` warning for process.

Evidence:
- Framework cards render correctly (3/3 tested with full recommendation + prefill)
- Consumer cards appear bare when `## Recommendation` is absent from task files
- Template line 87: `{% if t.recommendation %}` — hides entire context block
- Backend already extracts Go/No-Go Criteria as rationale_hint fallback, but ONLY for textarea — not for visible display
- User confirmed: "often you do it correct and often you forget" — recurring agent behavioral failure

Proposed build tasks (2):
1. Fix template to show fallback context (Go/No-Go Criteria, problem statement, warning) when recommendation is missing
2. Add warning to `fw task review` for inception tasks without substantive `## Recommendation`

### 2026-04-13T09:18:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
