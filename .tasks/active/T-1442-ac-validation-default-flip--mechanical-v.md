---
id: T-1442
name: "AC validation default-flip — mechanical verification with persisted evidence"
description: >
  AC validation default-flip — mechanical verification with persisted evidence

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [governance, ac-validation, friction-reduction]
components: []
related_tasks: [T-1443, T-954]
created: 2026-04-25T06:34:35Z
last_update: 2026-04-25T06:34:35Z
date_finished: null
---

# T-1442: AC validation default-flip — mechanical verification with persisted evidence

## Problem Statement

Human ACs are accumulating as approval-queue noise across multiple consumer projects. Many describe checks that don't require human judgment — they're mechanically evidenceable but currently default to Human review. Friction without proportional risk-management value.

**Goal:** frictionless development. **Constraint:** preserve antifragility + reliability + auditability. **Solution shape:** flip the default toward mechanical verification with persisted evidence; reserve Human AC for genuine judgment.

Full framing + dialogue genesis: `docs/reports/T-1442-ac-validation-default-flip.md`.

## Assumptions

1. Most current Human ACs are mechanically evidenceable in retrospect — UNTESTED (need sample audit across the existing backlog)
2. Persisting evidence (not just exit codes) materially improves auditability — LIKELY TRUE (reviewer agent in T-1443 needs evidence to assess)
3. Default-flip can extend T-954 / P-011 / `fw verify-acs` rather than replace them — UNTESTED (Q5a)
4. The three existing tiers (programmatic / TermLink E2E / Playwright) cover ≥90% of current Human-AC use cases — UNTESTED

## Exploration Plan

- **Spike A** (15m): Sample audit — pick 20 recent Human ACs, classify each as "mechanically evidenceable / genuinely human-judgment / ambiguous". Tests Assumption 1.
- **Spike B** (10m): Inventory existing controls (T-954 guidance, P-011 gate, `fw verify-acs` CLI, `fw test playwright`) and map their overlap. Tests Assumption 3.
- **Spike C** (15m): Draft the evidence-persistence shape (Q1) — append to task file vs `fw bus post` vs `docs/reports/T-XXX-evidence.md` vs combination.
- **Dialogue D**: Resolve Q3 (trigger model) with user — gate vs button vs combination. Shapes Q1 and Q5a.

## Technical Constraints

- Cannot add a hard pre-req gate without a fallback path (sovereignty: human can always override)
- Evidence persistence must survive context compaction (so Task tool sub-agent stdout is insufficient — must land on disk)
- Migration must be incremental — bulk re-classifying every existing Human AC across the backlog is out of scope (G-019: don't fix the past, prevent recurrence)

## Scope Fence

**IN:**
- Default classification policy (T-954 extension)
- Evidence persistence shape and protocol (Q1)
- Trigger model — when does mechanical verification fire (Q3)
- Relationship to existing controls (Q5a) — extend or replace
- Hand-off contract to T-1443 (reviewer agent's input shape)

**OUT:**
- Reviewer agent design (that's T-1443)
- Re-classifying existing Human ACs in bulk (incremental on next-touch only)
- Replacing P-011 verification gate (we extend, not replace)

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

## Research Artifact

See `docs/reports/T-1442-ac-validation-default-flip.md` — persisted thinking trail with framing, open questions, dialogue log. Updated incrementally as dialogue progresses (per C-001).

Linked sister inception: **T-1443** (reviewer agent design — captured, horizon=next, blocked on this inception's GO).

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
