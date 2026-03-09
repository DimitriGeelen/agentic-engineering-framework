---
id: T-396
name: "Risk management process: revive, merge, archive, or slim"
description: >
  Inception: Risk management process: revive, merge, archive, or slim

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-09T19:17:44Z
last_update: 2026-03-09T19:17:44Z
date_finished: null
---

# T-396: Risk management process: revive, merge, archive, or slim

## Problem Statement

The risk management process (risks.yaml, issues.yaml, controls.yaml) has become stale and disconnected from the operational framework. risks.yaml last updated Feb 19 (18 days ago), has no audit coverage, no CLI command, no CLAUDE.md reference, and no integration with healing, handover, or task lifecycle. Meanwhile gaps.yaml serves a similar function and IS fully integrated. Human raised concern about staleness.

Research artifact: `docs/reports/T-396-risk-management-disposition.md`

## Assumptions

- A1: Gaps.yaml can absorb risk-type entries without losing its current operational simplicity
- A2: The 4 open risks represent real concerns worth tracking (not just stale artifacts)
- A3: Archiving the risk register won't leave a forward-looking governance blind spot
- A4: External adopters can work with gaps.yaml + controls.yaml without a traditional risk register

## Exploration Plan

| # | Spike | Time-box | Deliverable |
|---|-------|----------|-------------|
| 1 | 5-perspective independent analysis | 30min | 5 agent reports (DONE) |
| 2 | Present options to human | 10min | Go/No-Go decision |

## Technical Constraints

- 4 YAML registers + web UI + audit integration to consider
- controls.yaml has backlinks to R-XXX IDs that must be handled
- Web routes (risks.py) and templates (risks.html) exist and render data
- Existing gap infrastructure (audit, CLAUDE.md, handover) is the integration target

## Scope Fence

**IN scope:** Disposition of risks.yaml, issues.yaml, controls.yaml; migration path; web UI changes
**OUT of scope:** New risk methodologies, additional governance frameworks, scoring model redesign

## Acceptance Criteria

### Agent
- [x] Problem statement validated with component fabric analysis
- [x] 5 independent perspectives gathered
- [x] Options presented with trade-offs
- [ ] Go/No-Go decision recorded

### Human
- [ ] [REVIEW] Choose disposition option (A/B/C/D)
  **Steps:**
  1. Read `docs/reports/T-396-risk-management-disposition.md`
  2. Consider the 4 options and score card
  **Expected:** Clear direction chosen
  **If not:** Discuss trade-offs further

## Go/No-Go Criteria

**GO if:**
- Human chooses a clear disposition option
- Chosen option can be implemented in one session

**NO-GO if:**
- Analysis reveals the registers serve a critical function we missed
- No consensus on direction (need more data)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Option D: Consolidate risks+gaps into unified concerns register. Scored 8.2/10 across directives. Eliminates 'which register?' cognitive tax, inherits all gap infrastructure, preserves forward-looking capacity via type:risk entries. Delete issues.yaml (duplicates episodic+patterns). ~3 hours.

**Date**: 2026-03-09T20:07:38Z
## Decision

**Decision**: GO

**Rationale**: Option D: Consolidate risks+gaps into unified concerns register. Scored 8.2/10 across directives. Eliminates 'which register?' cognitive tax, inherits all gap infrastructure, preserves forward-looking capacity via type:risk entries. Delete issues.yaml (duplicates episodic+patterns). ~3 hours.

**Date**: 2026-03-09T20:07:38Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-09T20:07:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Option D: Consolidate risks+gaps into unified concerns register. Scored 8.2/10 across directives. Eliminates 'which register?' cognitive tax, inherits all gap infrastructure, preserves forward-looking capacity via type:risk entries. Delete issues.yaml (duplicates episodic+patterns). ~3 hours.
