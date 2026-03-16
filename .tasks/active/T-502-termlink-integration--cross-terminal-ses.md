---
id: T-502
name: "TermLink integration — cross-terminal session communication for framework"
description: >
  Explore integrating TermLink (our cross-terminal session communication tool, Rust, 26 commands)
  into the framework as an optional external tool. Pickup message from TermLink repo (T-148).
  Assess: scope, platform constraints, phased rollout, decomposition into build tasks.

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [termlink, integration, cross-terminal]
components: [bin/fw]
related_tasks: []
created: 2026-03-15T23:43:34Z
last_update: 2026-03-15T23:58:35Z
date_finished: 2026-03-15T23:58:35Z
---

# T-502: TermLink integration — cross-terminal session communication for framework

## Problem Statement

The framework has no mechanism for cross-terminal communication. Agents cannot spawn parallel
workers in real terminals, observe other sessions, or coordinate multi-machine workflows.
TermLink (our Rust tool, 26 commands, 264 tests) already solves this at the binary level.
The framework needs an integration layer to make TermLink's capabilities available through
`fw` commands and governed by framework rules (task-tagging, budget limits, cleanup).

**Source:** Pickup message from TermLink repo session (T-148 on OneDev).
**Research artifact:** `docs/reports/T-502-termlink-integration-inception.md`

## Assumptions

- A1: TermLink binary is stable enough for framework integration (264 tests, 26 commands)
- A2: Terminal spawning (osascript on macOS, gnome-terminal on Linux) is the right approach
- A3: A thin wrapper (task-tagging + budget checks) is sufficient — no need to rebuild TermLink features
- A4: Phase 0 (doctor check + agent wrapper + route + docs) can be built independently of Phases 1-4
- A5: The framework server (headless Linux) can still benefit from TermLink (interact, events, hub — no terminal spawning)

## Exploration Plan

| # | Spike | Time-box | Deliverable |
|---|-------|----------|-------------|
| 1 | Assess pickup spec | 10min | Research artifact with gap analysis |
| 2 | Platform check | 5min | Can TermLink be installed/used on this server? |
| 3 | Scope Phase 0 | 10min | Concrete deliverable list with size estimate |
| 4 | Go/No-Go | 5min | Decision with rationale |

## Technical Constraints

- **TermLink not installed on framework server** — headless Linux, no terminal emulator
- **Terminal spawning is macOS-specific** — osascript for Terminal.app; Linux uses gnome-terminal fallback
- **TermLink repo on OneDev** — `https://onedev.docker.ring20.geelenandcompany.com/termlink`
- **3-phase terminal cleanup required** — learned from T-074/T-143 in TermLink repo
- **Reference implementation exists** — `scripts/tl-dispatch.sh` (tested with 3 parallel workers)

## Scope Fence

**IN scope:** Assess Phase 0 from the pickup spec. Determine if it's ready for build tasks.

**OUT of scope:** Phases 1-4 (self-test, parallel dispatch, remote control, cross-machine).
Building any code (that's for build tasks after GO decision).

## Acceptance Criteria

### Agent
- [x] Research artifact written to `docs/reports/T-502-termlink-integration-inception.md`
- [x] Pickup spec assessed — scope, platform constraints, gaps identified
- [x] Phase 0 scope defined with concrete deliverables
- [x] Go/No-Go recommendation presented with rationale

### Human
- [ ] [REVIEW] Review TermLink integration approach and decide go/no-go
  **Steps:**
  1. Read `docs/reports/T-502-termlink-integration-inception.md`
  2. Assess: is Phase 0 scope right? Any missing concerns?
  3. Decide: GO (proceed to build tasks) or NO-GO (defer/narrow)
  **Expected:** Clear direction on Phase 0 build
  **If not:** Flag specific concerns for further exploration

## Go/No-Go Criteria

**GO if:**
- Phase 0 scope is small and well-defined (≤5 deliverables)
- TermLink is our own project with tested reference implementation
- Integration is optional (WARN not FAIL, graceful degradation)
- Clear phase boundaries with no cross-phase dependencies

**NO-GO if:**
- Scope is too large or unclear for a single build task
- Platform constraints make the integration impractical
- TermLink binary is not stable enough for framework dependency
- The phased rollout has hidden dependencies we can't resolve

## Verification

test -f docs/reports/T-502-termlink-integration-inception.md

## Decisions

**Decision**: GO

**Rationale**: Phase 0 is small (5 deliverables), TermLink is our own project with tested reference impl, optional integration with graceful degradation. One build task: T-503.

**Date**: 2026-03-15T23:58:12Z
## Decision

**Decision**: GO

**Rationale**: Phase 0 is small (5 deliverables), TermLink is our own project with tested reference impl, optional integration with graceful degradation. One build task: T-503.

**Date**: 2026-03-15T23:58:12Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-15T23:58:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Phase 0 is small (5 deliverables), TermLink is our own project with tested reference impl, optional integration with graceful degradation. One build task: T-503.

### 2026-03-15T23:58:20Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-03-15T23:58:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
