---
id: T-1298
name: "Pickup: Inception template GO/NO-GO placeholders propagate to auto-created tasks — detected only at decide time (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink. Type: pattern.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, pattern]
components: [lib/task-audit.sh, tests/unit/lib_task_audit.bats]
related_tasks: []
created: 2026-04-18T15:21:41Z
last_update: 2026-04-22T05:19:25Z
date_finished: 2026-04-22T05:19:25Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1298: Pickup: Inception template GO/NO-GO placeholders propagate to auto-created tasks — detected only at decide time (from termlink)

## Problem Statement

Pickup reports: the inception template ships with generic GO/NO-GO default criteria that propagate into every pickup-derived inception. The framing is that the problem is "detected only at decide time". Full triage: `docs/reports/T-1298-inception-go-no-go-defaults.md`.

## Assumptions

1. Generic GO/NO-GO defaults are flagged by some gate — TESTED FALSE (no detector catches them)
2. Template edit would be a surgical fix — TESTED TRUE (defaults live in exactly one file)
3. Concrete inception regrets traceable to generic Go/No-Go exist — NO EVIDENCE found in current session data

## Exploration Plan

Time-boxed: 10 min investigation (done in session S-2026-0419-0047+).

- Locate where the literal defaults live (grep) — DONE: `.tasks/templates/inception.md` only
- Inspect `audit_task_placeholders` patterns — DONE: catches 5 bracket-style patterns, not literal prose
- Inspect `do_inception_decide` gates — DONE: placeholder audit + review marker + recommendation content
- Search for concrete misses attributable to generic Go/No-Go — DONE: none found

## Technical Constraints

None — this is a governance/process question, not a technical one.

## Scope Fence

**IN:** decide whether to add Go/No-Go customization gating in the inception flow.
**OUT:** redesigning the inception lifecycle, adding other quality gates, editing the template beyond Go/No-Go defaults.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (pickup's premise is inaccurate — framework does NOT detect these at decide time)
- [x] Assumptions tested (1 false, 1 true, 1 no-evidence)
- [x] Recommendation written with rationale (DEFER — see Recommendation section)

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

**Recommendation:** DEFER

**Rationale:** The pickup's premise — that the framework catches generic Go/No-Go defaults at decide time — is inaccurate. No existing detector flags them (`audit_task_placeholders` looks for `[Criterion N]` / `[TODO]` / `[PLACEHOLDER]` / `[Your recommendation here]` / `[REQUIRED before` — all bracket-style, not the literal prose of the defaults). Adding a new gate to catch them would introduce friction on every triage without a concrete failure that motivates it. No current evidence shows that generic Go/No-Go has caused a regretted decision. Revisit if: (a) three or more inception decisions are later regretted and the post-mortem traces to generic Go/No-Go failing to discriminate, OR (b) human requests the gate explicitly.

**Evidence:**
- `.tasks/templates/inception.md:64-69` contains the literal defaults — only file in the repo that does (grep-verified)
- `lib/task-audit.sh:audit_task_placeholders` pattern list explicitly does NOT include them
- `lib/inception.sh:do_inception_decide` gates: placeholder audit, review marker, recommendation-content check — none hit the defaults
- No incidents in `.context/project/learnings.yaml` or `concerns.yaml` reference generic Go/No-Go as causing a miss
- Full triage: `docs/reports/T-1298-inception-go-no-go-defaults.md`

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER

Rationale: The pickup's premise — that the framework catches generic Go/No-Go defaults at decide time — is inaccurate. No existing detector flags them (`audit_task_placeholders` looks for `[Criterion N]` / `[TODO]` / `[PLACEHOLDER]` / `[Your recommendation here]` / `[REQUIRED before` — all bracket-style, not the literal prose of the defaults). Adding a new gate to catch them would introduce friction on every triage without a concrete failure that motivates it. No current evidence shows that generic Go/No-Go has caused a regretted decision. Revisit if: (a) three or more inception decisions are later regretted and the post-mortem traces to generic Go/No-Go failing to discriminate, OR (b) human requests the gate explicitly.

Evidence:
- `.tasks/templates/inception.md:64-69` contains the literal defaults — only file in the repo that does (grep-verified)
- `lib/task-audit.sh:audit_task_placeholders` pattern list explicitly does NOT include them
- `lib/inception.sh:do_inception_decide` gates: placeholder audit, review marker, recommendation-content check — none hit the defaults
- No incidents in `.context/project/learnings.yaml` or `concerns.yaml` reference generic Go/No-Go as causing a miss
- Full triage: `docs/reports/T-1298-inception-go-no-go-defaults.md`

**Date**: 2026-04-20T09:40:49Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-19T08:08:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-20T09:40:49Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER

Rationale: The pickup's premise — that the framework catches generic Go/No-Go defaults at decide time — is inaccurate. No existing detector flags them (`audit_task_placeholders` looks for `[Criterion N]` / `[TODO]` / `[PLACEHOLDER]` / `[Your recommendation here]` / `[REQUIRED before` — all bracket-style, not the literal prose of the defaults). Adding a new gate to catch them would introduce friction on every triage without a concrete failure that motivates it. No current evidence shows that generic Go/No-Go has caused a regretted decision. Revisit if: (a) three or more inception decisions are later regretted and the post-mortem traces to generic Go/No-Go failing to discriminate, OR (b) human requests the gate explicitly.

Evidence:
- `.tasks/templates/inception.md:64-69` contains the literal defaults — only file in the repo that does (grep-verified)
- `lib/task-audit.sh:audit_task_placeholders` pattern list explicitly does NOT include them
- `lib/inception.sh:do_inception_decide` gates: placeholder audit, review marker, recommendation-content check — none hit the defaults
- No incidents in `.context/project/learnings.yaml` or `concerns.yaml` reference generic Go/No-Go as causing a miss
- Full triage: `docs/reports/T-1298-inception-go-no-go-defaults.md`

### 2026-04-22T05:19:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-556a0544
- **Timestamp:** 2026-06-02T14:56:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
