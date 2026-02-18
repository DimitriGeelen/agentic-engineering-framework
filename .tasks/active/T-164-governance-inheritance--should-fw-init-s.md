---
id: T-164
name: "Governance inheritance — should fw init seed practices and patterns from framework"
description: >
  Inception: Governance inheritance — should fw init seed practices and patterns from framework

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:39:19Z
last_update: 2026-02-18T13:39:35Z
date_finished: null
---

# T-164: Governance inheritance — should fw init seed practices and patterns from framework

## Problem Statement

`fw init` creates empty `practices.yaml` for new projects, causing them to lose 96 tasks worth of operational learning codified into 10 framework practices. Sprechloop has **0 practices** despite 33 completed tasks and 16 learnings. All 10 framework practices (P-001 through P-010) are universal — they define how the framework operates, not project-specific knowledge. Same applies to workflow/success patterns. A new project without these practices operates without the framework's accumulated operational intelligence.

**Research reports:** `.context/research/T-164-framework-governance.md`, `.context/research/T-164-sprechloop-governance.md`

## Evidence (from parallel audits)

**Framework governance:** 10 practices, 26 decisions, 53 learnings, 22 patterns, 8 gaps, 4 directives — 149 total entries, 99.3% traced
**Sprechloop governance:** 0 practices, 8 decisions, 16 learnings, 5 patterns, 4 gaps, 4 directives — 37 total entries

**All 10 framework practices are universal:**
- P-001 Measure What Exists, Not What Should Exist
- P-002 Structural Enforcement Over Agent Discipline
- P-003 Adoption Before Measurement
- P-004 Distinguish Existence from Quality
- P-005 Bootstrap Exceptions Are First-Class
- P-006 Hybrid Agent Architecture
- P-007 Systematic Session Capture
- P-008 Tasks Must Carry Executable Context
- P-009 Context Budget Awareness
- P-010 Validate AC Before Closing Tasks

**Three categories of governance data identified:**
1. **Inherited** (same across projects): Directives, Practices, Workflow/success patterns
2. **Seeded** (framework provides starting templates): Failure patterns as cautionary reference
3. **Project-specific** (never inherited): Decisions, Learnings, Gaps, Assumptions

## Assumptions

- A1: All 10 framework practices are universal (not project-specific) — VALIDATED by analysis
- A2: `fw init` is the correct injection point for inheritance — TO TEST
- A3: Projects benefit from framework patterns as starting reference — TO TEST (sprechloop G-003 suggests yes)

## Exploration Plan

1. Validate practice universality (done — all 10 apply to any project)
2. Evaluate inheritance models: copy vs reference vs tiered
3. Spike: modify `fw init` / `lib/init.sh` to seed practices
4. Determine sync mechanism for practice updates

## Technical Constraints

- `lib/init.sh` creates `.context/project/` files from templates
- Practices reference directives (D1-D4) which are already inherited
- Projects may need to override or extend practices (not just copy)

## Scope Fence

**IN scope:** practices.yaml inheritance, pattern seeding, fw init changes, sync mechanism design
**OUT of scope:** Decision/learning inheritance (always project-specific), automated cross-project sync

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Evidence that missing practices caused real issues (sprechloop G-003 confirms)
- Inheritance model is simple enough to implement in one session

**NO-GO if:**
- Practices are too project-specific to inherit (disproven — all 10 are universal)
- Inheritance creates maintenance burden worse than manual copying

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
