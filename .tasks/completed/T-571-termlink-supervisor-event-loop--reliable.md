---
id: T-571
name: "TermLink supervisor event loop — reliable bidirectional signaling between supervisor and dispatched agents"
description: >
  Inception: TermLink supervisor event loop — reliable bidirectional signaling between supervisor and dispatched agents

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T20:56:23Z
last_update: 2026-04-13T06:23:21Z
date_finished: 2026-03-28T17:09:43Z
---

# T-571: TermLink supervisor event loop — reliable bidirectional signaling between supervisor and dispatched agents

## Problem Statement

Current `fw termlink dispatch` is fire-and-forget with file-based polling. Workers can crash, hang, or orphan without the dispatcher knowing until a hard timeout (600s). No heartbeat, no graceful shutdown, no crash recovery. As TermLink dispatch becomes the preferred mechanism for heavy parallel work (T-630), these reliability gaps become blocking.

## Assumptions

- A1: TermLink event primitives are reliable enough for supervision (VALIDATED — <10ms latency, used in current dispatch)
- A2: Session disappearance is detectable via discover/status (VALIDATED — both report session state)
- A3: Worker-side heartbeat is feasible (PARTIALLY VALIDATED — background process works, CPU starvation under heavy claude -p load untested)
- A4: The supervisor loop is needed now (NOT VALIDATED — current dispatch handles 1-3 workers adequately, no data loss incidents yet)

## Exploration Plan

1. Audit TermLink event primitives (done — emit/wait/poll/broadcast available)
2. Evaluate 3 supervisor architecture options (done — bash loop vs heartbeat vs Rust-native)
3. Assess crash detection strategies (done — session-gone via discover is simplest)
4. Design graceful shutdown protocol (done — broadcast + SIGTERM + SIGKILL escalation)
5. Make recommendation (done — Conditional GO for Phase 1 lightweight approach)

## Technical Constraints

- TermLink event system is pub-sub, session-scoped
- Bash supervisor loops are coarse (sleep-based polling)
- `claude -p` workers consume significant CPU — heartbeat processes may starve
- Max 5 parallel workers per CLAUDE.md dispatch protocol

## Scope Fence

**IN:** Whether to build a supervisor event loop, which architecture, what phases.
**OUT:** Implementing the supervisor (separate build task). TermLink Rust-level changes. Cross-machine supervision.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (4 assumptions — 2 validated, 1 partial, 1 not validated)
- [x] Go/No-Go recommendation made (CONDITIONAL GO — Phase 1 lightweight)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-571-termlink-supervisor-event-loop.md`
  2. Evaluate whether Phase 1 (crash detection + graceful shutdown) is worth building now vs deferring entirely
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-571 go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Crash detection can use existing TermLink primitives (discover, status) — no new infrastructure
- Phase 1 fits in one build session (<4 hours)
- Current dispatch reliability is insufficient for >3 parallel workers

**NO-GO if:**
- Current dispatch with cleanup is adequate (no data loss incidents)
- Phase 1 adds complexity without proportional reliability gain
- TermLink dispatch is not yet the primary dispatch mechanism

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Crash detection can use existing TermLink primitives (discover, status) — no new infrastructure; Phase 1 fits in one build session (<4 hours); Current dispatch reliability is insufficient for >3 pa...

## Decisions

**Decision**: GO

**Rationale**: Crash detection can use existing TermLink primitives (discover, status) — no new infrastructure; Phase 1 fits in one build session (<4 hours); Current dispatch reliability is insufficient for >3 pa...

**Date**: 2026-03-28T17:09:43Z
## Decision

**Decision**: GO

**Rationale**: Crash detection can use existing TermLink primitives (discover, status) — no new infrastructure; Phase 1 fits in one build session (<4 hours); Current dispatch reliability is insufficient for >3 pa...

**Date**: 2026-03-28T17:09:43Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-03-28 — artifact-reference [audit-fix]
- **Research artifact:** docs/reports/T-571-termlink-supervisor-event-loop.md

### 2026-03-28T17:09:43Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Crash detection can use existing TermLink primitives (discover, status) — no new infrastructure; Phase 1 fits in one build session (<4 hours); Current dispatch reliability is insufficient for >3 pa...

### 2026-03-28T17:09:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
