---
id: T-1283
name: "Prompt register in Watchtower — reusable agent prompts (upgrade+test+fix, dispatch, audit, etc.)"
description: >
  Inception: Prompt register in Watchtower — reusable agent prompts (upgrade+test+fix, dispatch, audit, etc.)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-17T16:04:15Z
last_update: 2026-04-26T19:30:17Z
date_finished: null
---

# T-1283: Prompt register in Watchtower — reusable agent prompts (upgrade+test+fix, dispatch, audit, etc.)

## Problem Statement

Reusable agent prompts (cross-machine upgrade+test+fix, audit dispatch, fleet 
reauth, onboarding) are currently crafted ad-hoc in chat and lost at session 
end. No place to store, version, share, or iterate canonical prompts. Triggered 
by the upgrade+test+fix prompt drafted for ring20-dashboard (.121) during this 
session — saved as the seed artifact.

## Assumptions

- A1: Agents across the fleet will benefit from shared prompts (not just 107-local).
- A2: Simple `{{var}}` substitution covers 95% of real prompt parameterization.
- A3: Git history is sufficient as the "version" mechanism — no custom versioning layer needed.
- A4: Last-write-wins with git audit trail is acceptable for sync conflicts.
- A5: Users will use the composer form via Watchtower, not hand-edit files.

## Exploration Plan

See full artifact: docs/reports/T-1283-prompt-register.md

Decisions recorded for all 6 questions:
- Q1 storage = markdown + frontmatter
- Q2 params = simple `{{var}}` (best on all 4 directives)
- Q3 scope = unified store with kind/tag differentiation
- Q4 sharing = fleet-wide via TermLink sync from day 1
- Q5 lifecycle = capture-and-refine + IDs `<agent-id>/P-NNN` for cross-agent
- Q6 UI = list + detail + composer form

## Technical Constraints

- ID uniqueness across fleet (namespacing by agent-id required since Q4=fleet-wide)
- Sync protocol must be offline-first (works when fleet unreachable)
- TermLink auth required for sync — existing hub auth model reused
- Watchtower composer form binds to Flask backend — T-1260 CLAUDECODE guard 
  blocker applies (cross-dependency with B3/B4 and T-1260)

## Scope Fence

**IN scope:** prompt file schema, CLI (create/list/show/copy/sync), ID 
namespacing, Watchtower list+detail+copy+composer UI, fleet sync via TermLink, 
conflict-resolution policy.

**OUT of scope:** auto-prompt generation from conversation history, prompt 
execution runner (prompts stay text; execution is the agent's job), 
multi-language prompt templates (future).

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
- All 6 design questions have clear decisions (✓ done, see artifact)
- Scope decomposable into bounded build units (✓ B1-B6 identified)
- Each build unit fits in one session or has clear split points
- Core assumption A1 (fleet value > local value) holds given Q4=fleet-wide
- No unresolved dependencies on broken infrastructure (T-1260 is a parallel 
  build, not a blocker — MVP B1-B3 runs without Watchtower composer)

**NO-GO if:**
- Fleet-sync adds more complexity than the prompts save (would invalidate Q4)
- Composer form cannot be built until T-1260 is resolved (would block B4)
- Unique-ID scheme collides with existing framework namespaces (blocks B2)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO (full scope, B1-B6)

**Rationale:** All 6 design questions resolved with directive-aligned decisions. 
The user selected full scope after reviewing MVP-vs-full tradeoff. Fleet-sync 
(Q4=b) and composer UI (Q6=b) are deliberate investments because prompt value 
is cross-agent refinement — building MVP-only would underdeliver on the core 
premise. Scope is bounded into 6 discrete build units with phased release 
points (B1-B3 usable standalone; B4-B6 build on top).

**Evidence:**
- Seed prompt captured and saved (docs/reports/T-1283-prompt-register.md)
- All 6 questions answered, including directive-scored analysis of Q2 
  (simple `{{var}}` beats template engines on all four directives)
- Unique-ID scheme designed (`<agent-id>/P-NNN`) that reuses existing 
  TermLink host-tagging convention — no new namespace to invent
- Fleet-sync protocol sketched: push/pull/sync verbs, offline-first, 
  last-write-wins with git audit
- 6 build units decomposed with dependencies clear (B1 → B2 → B3 → B4 → B5 → B6)
- Parallel dependency on T-1260 (CLAUDECODE Flask guard) affects B4 only — 
  does not block MVP (B1-B3)

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

**Rationale**: Recommendation: GO (full scope, B1-B6)

Rationale: All 6 design questions resolved with directive-aligned decisions. 
The user selected full scope after reviewing MVP-vs-full tradeoff. Fleet-sync 
(Q4=b) and composer UI (Q6=b) are deliberate investments because prompt value 
is cross-agent refinement — building MVP-only would underdeliver on the core 
premise. Scope is bounded into 6 discrete build units with phased release 
points (B1-B3 usable standalone; B4-B6 build on top).

Evidence:
- Seed prompt captured and saved (docs/reports/T-1283-prompt-register.md)
- All 6 questions answered, including directive-scored analysis of Q2 
  (simple `{{var}}` beats template engines on all four directives)
- Unique-ID scheme designed (`<agent-id>/P-NNN`) that reuses existing 
  TermLink host-tagging convention — no new namespace to invent
- Fleet-sync protocol sketched: push/pull/sync verbs, offline-first, 
  last-write-wins with git audit
- 6 build units decomposed with dependencies clear (B1 → B2 → B3 → B4 → B5 → B6)
- Parallel dependency on T-1260 (CLAUDECODE Flask guard) affects B4 only — 
  does not block MVP (B1-B3)

**Date**: 2026-04-17T19:19:23Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-17T16:07:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-17T19:18:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (full scope, B1-B6)

Rationale: All 6 design questions resolved with directive-aligned decisions. 
The user selected full scope after reviewing MVP-vs-full tradeoff. Fleet-sync 
(Q4=b) and composer UI (Q6=b) are deliberate investments because prompt value 
is cross-agent refinement — building MVP-only would underdeliver on the core 
premise. Scope is bounded into 6 discrete build units with phased release 
points (B1-B3 usable standalone; B4-B6 build on top).

Evidence:
- Seed prompt captured and saved (docs/reports/T-1283-prompt-register.md)
- All 6 questions answered, including directive-scored analysis of Q2 
  (simple `{{var}}` beats template engines on all four directives)
- Unique-ID scheme designed (`<agent-id>/P-NNN`) that reuses existing 
  TermLink host-tagging convention — no new namespace to invent
- Fleet-sync protocol sketched: push/pull/sync verbs, offline-first, 
  last-write-wins with git audit
- 6 build units decomposed with dependencies clear (B1 → B2 → B3 → B4 → B5 → B6)
- Parallel dependency on T-1260 (CLAUDECODE Flask guard) affects B4 only — 
  does not block MVP (B1-B3)

### 2026-04-17T19:19:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (full scope, B1-B6)

Rationale: All 6 design questions resolved with directive-aligned decisions. 
The user selected full scope after reviewing MVP-vs-full tradeoff. Fleet-sync 
(Q4=b) and composer UI (Q6=b) are deliberate investments because prompt value 
is cross-agent refinement — building MVP-only would underdeliver on the core 
premise. Scope is bounded into 6 discrete build units with phased release 
points (B1-B3 usable standalone; B4-B6 build on top).

Evidence:
- Seed prompt captured and saved (docs/reports/T-1283-prompt-register.md)
- All 6 questions answered, including directive-scored analysis of Q2 
  (simple `{{var}}` beats template engines on all four directives)
- Unique-ID scheme designed (`<agent-id>/P-NNN`) that reuses existing 
  TermLink host-tagging convention — no new namespace to invent
- Fleet-sync protocol sketched: push/pull/sync verbs, offline-first, 
  last-write-wins with git audit
- 6 build units decomposed with dependencies clear (B1 → B2 → B3 → B4 → B5 → B6)
- Parallel dependency on T-1260 (CLAUDECODE Flask guard) affects B4 only — 
  does not block MVP (B1-B3)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-19fab1c0
- **Timestamp:** 2026-06-02T14:56:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
