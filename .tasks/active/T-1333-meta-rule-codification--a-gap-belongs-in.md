---
id: T-1333
name: "Meta-rule codification — a gap belongs in the register where the fix lives, not where it was hit"
description: >
  Inception: Meta-rule codification — a gap belongs in the register where the fix lives, not where it was hit

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-19T13:03:02Z
last_update: 2026-04-19T13:03:02Z
date_finished: null
---

# T-1333: Meta-rule codification — a gap belongs in the register where the fix lives, not where it was hit

## Problem Statement

050-email-archive proposed a governance meta-rule (2026-04-19): **"A gap belongs in the register where the FIX lives, not where it was HIT."** Their case: G-014 "agent-daemon-not-injectable" is filed in ring20-management's concerns.yaml, but the fix is a termlink-schema change (session caps + RPC method absence on data_plane+stream sessions). Any consumer that hits it will not discover the entry because they search their own register, not ring20-management's.

Question: **should this rule be codified in CLAUDE.md (and possibly enforced via a concerns.yaml cross-reference field), or is it a one-off situational judgement that doesn't generalize?**

## Assumptions

1. The homing ambiguity (fix-locus vs hit-locus) recurs across projects — UNTESTED (need to audit concerns.yaml entries across the fleet)
2. Codifying in CLAUDE.md would be followed — LIKELY TRUE (agents consult CLAUDE.md before filing new gaps)
3. Structural enforcement (e.g., required `fix-locus` field in concerns.yaml schema) would be tractable — UNTESTED

## Exploration Plan

- **A** (10m): Scan all concerns.yaml across known consumer projects — flag entries where hit-locus ≠ fix-locus (or ambiguous)
- **B** (5m): Draft the CLAUDE.md section (rule + one concrete example + when-to-apply)
- **C** (5m): Decide codification tier — CLAUDE.md prose (Tier 1) vs schema field (Tier 2) vs audit check (Tier 3)

## Technical Constraints

- CLAUDE.md changes propagate via framework upgrade to consumers (baseline CLAUDE.md lives in framework repo)
- A schema field change on concerns.yaml would require audit + migration for existing entries
- Not every gap has an obvious single "fix locus" — some have cross-cutting fixes

## Scope Fence

**IN:** decide whether to codify the meta-rule, and at what enforcement tier.
**OUT:** actually reviewing and re-homing existing concerns (that's follow-up work per-project, not framework-level).

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
