---
id: T-124
name: Validate framework new-project onboarding via live sprechloop experiment
description: >
  Multi-cycle live experiment using /opt/001-sprechloop as test bed.
  Protocol: fresh session → observe → document O-XXX → analyze → fix → verify → repeat.
  Done when two consecutive cycles produce zero new P0/P1 observations.
  Tutorial documentation is a downstream task, spawned only on GO decision.
status: work-completed
workflow_type: inception
horizon: now
owner: human
tags: [onboarding, validation, sprechloop]
related_tasks: [T-125, T-126, T-127, T-128, T-129]
created: 2026-02-17T19:06:03Z
last_update: 2026-02-18T09:44:40Z
date_finished: 2026-02-18T09:44:40Z
---

# T-124: Validate framework new-project onboarding via live sprechloop experiment

## Problem Statement

The framework has 123 completed tasks but has never been validated on an external project. The first attempt (sprechloop, cycle 1) produced 10 observations (3x P0, 7x P1) revealing that new projects get incomplete governance, inception tasks have no structural gate, and the agent runs ahead without user interaction.

**Core question:** Is the framework ready for external project use?

## Assumptions

- A-1: CLAUDE.md content is the primary driver of agent behavior in new projects
- A-2: Structural gates (hooks) are more reliable than instruction-based enforcement
- A-3: The sprechloop experiment is representative of general external project onboarding
- A-4: Two consecutive clean cycles is sufficient evidence of readiness

## Exploration Plan

Multi-cycle experiment. Each cycle: reset → observe → document → fix → record.
See `docs/cycle2-protocol.md` for detailed protocol.

**Child tasks (fixes):**
- T-125: First-session orientation (O-001, O-004)
- T-126: Inception commit gate (O-003, O-005) — **most critical**
- T-127: Template sync + behavioral rules (O-002, O-006, O-007, O-009)
- T-128: Circuit breaker (O-008) — horizon: next
- T-129: Inception template constraints (O-010) — horizon: next

## Scope Fence

**IN scope:**
- Running experiment cycles on sprechloop
- Documenting observations
- Creating and completing fix tasks
- Go/no-go decision on framework readiness

**OUT of scope:**
- Building the sprechloop app itself (that's sprechloop's own tasks)
- Writing the onboarding tutorial (post-GO task)
- Fundamental framework redesign

## Acceptance Criteria

- [x] All P0 observations have completed fix tasks (T-126, T-127)
- [x] Two consecutive PASS cycles (zero new P0/P1)
- [x] No regressions in final two cycles
- [x] Fresh `fw init` project includes all governance sections

## Go/No-Go Criteria

**GO if:** All AC met. Two consecutive PASS cycles.
**NO-GO if:** After 7 cycles still generating P0, or O-003/O-005 re-occurs after T-126.

## Verification

# Verify template includes all critical sections
grep -q "Verification Gate" lib/templates/claude-project.md
grep -q "Horizon" lib/templates/claude-project.md
grep -q "Task Sizing" lib/templates/claude-project.md

## Decisions

**Decision**: GO

**Rationale**: Two consecutive clean Watchtower audits (cycles 5-6). All 14 pages pass on sprechloop :3001. 6 cycles total: 4 FAIL (found and fixed 12+ bugs across init.sh, create-task.sh, knowledge capture, budget-gate), 2 PASS. Framework onboarding produces a fully functional monitored project.

**Date**: 2026-02-18T09:43:43Z

## Evidence

- `docs/onboarding-observations.md` — raw observation log (O-001 through O-010+)
- `docs/observation-analysis.md` — classification, clusters, root causes
- `docs/task-structure-proposal.md` — task decomposition and experiment design
- `docs/cycle2-protocol.md` — specific behaviors to test and metrics
- `docs/onboarding-cycles.md` — per-cycle results

## Updates

### 2026-02-17T19:06:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Context:** Initial creation as build task

### 2026-02-17T20:15:00Z — re-scoped [human + agent]
- **Action:** Re-scoped from build to inception after cycle 1 analysis
- **Context:** 10 observations (3x P0), 3 root causes identified, 5 child tasks designed

### 2026-02-18T09:43:43Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Two consecutive clean Watchtower audits (cycles 5-6). All 14 pages pass on sprechloop :3001. 6 cycles total: 4 FAIL (found and fixed 12+ bugs across init.sh, create-task.sh, knowledge capture, budget-gate), 2 PASS. Framework onboarding produces a fully functional monitored project.

### 2026-02-18T09:44:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
