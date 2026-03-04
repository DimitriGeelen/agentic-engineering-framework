---
id: T-306
name: "Inception: framework distribution model — split vs self-contained"
description: >
  The current shared tooling model has the framework repo serving two roles: (1) self-hosting development project using its own governance, (2) live tool consumed by other projects. This creates version mingling — other projects execute live agents but hold frozen copies of CLAUDE.md, settings.json, seeds, templates. Half the project runs at init-time version, half at current version. This inception explores: how to create a clean distribution boundary between the self-hosting dev repo and what other projects consume. Constraint: the framework MUST remain self-hosting (it develops itself using its own tooling). The dev repo stays. The question is how other projects get a clean, versioned, non-entangled copy. Options include: versioned releases, vendored distribution, clean CLI separation. Related research: docs/reports/T-294-framework-onboarding-portable-bootstrap.md (Area 1, DX comparison). Source: T-294 dialogue — user identified split model as architecturally problematic.

status: started-work
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T16:41:57Z
last_update: 2026-03-04T18:53:12Z
date_finished: null
---

# T-306: Inception: framework distribution model — split vs self-contained

## Problem Statement

The framework's shared tooling model creates version mingling: consumer projects run live agents/scripts (always at HEAD) but hold frozen copies of CLAUDE.md, settings.json, seeds, and templates (captured at init-time). When the framework evolves, half the consumer project runs at the current version and half at the init-time version, causing confusing failures. **For:** any project using the framework via `fw init`. **Why now:** Phase 1-3 onboarding work (T-295–T-304) is complete — the init flow works but the underlying distribution model hasn't been addressed.

## Assumptions

A-001: Version mingling causes real breakage (not just theoretical)
A-002: Consumer projects need all framework agents, not a subset
A-003: Frozen artifacts diverge meaningfully over time
A-004: Users can tolerate a "pull + migrate" workflow for updates

## Exploration Plan

1. **Spike 1 (30min):** Map exact version-sensitive touchpoints — which frozen artifacts reference which live components, and where breaking changes would manifest
2. **Spike 2 (30min):** Prototype `fw upgrade` command — re-run frozen artifact generation, diff with existing, present changes to user
3. **Dialogue:** Present options to human, get direction on distribution model preference

## Technical Constraints

- Framework MUST remain self-hosting (develops itself with own governance)
- Consumer projects may be on different machines (no guaranteed network to framework repo)
- Git hooks reference framework path at install time
- CLAUDE.md is loaded by Claude Code at session start — must be a real file, not symlink

## Scope Fence

**IN scope:** Analysis of version mingling touchpoints, prototype of `fw upgrade`, go/no-go on distribution model change
**OUT of scope:** Package manager distribution (premature), full implementation of chosen approach, Watchtower distribution

## Acceptance Criteria

- [ ] Problem statement validated with concrete version mismatch examples
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Version mingling causes (or will cause) real breakage in consumer projects
- A clean upgrade path can be built without breaking self-hosting

**NO-GO if:**
- Version mingling is cosmetic only (no functional breakage)
- Every option requires abandoning the shared tooling model entirely

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

### 2026-03-04T18:53:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
