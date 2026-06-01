---
id: T-598
name: "Inception: Bridge fw dispatch to TermLink file/remote — replace SSH text pipe with native hub routing and file transfer"
description: >
  TermLink already has file send/receive, hub server, and remote commands. But fw dispatch only sends JSON text over SSH. Bridge the gap: wire fw bus/dispatch to use termlink file send, termlink remote send-file, and termlink hub for cross-machine communication. Research why the previous attempt failed, what TermLink capabilities exist, and design the integration.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-24T09:05:48Z
last_update: 2026-04-13T06:23:22Z
date_finished: 2026-03-28T17:08:25Z
---

# T-598: Inception: Bridge fw dispatch to TermLink file/remote — replace SSH text pipe with native hub routing and file transfer

## Problem Statement

`fw dispatch send` uses raw SSH pipes with inline JSON envelopes. TermLink already has `file send`, `remote send-file`, `hub` routing, and `remote exec` — but these are completely disconnected from the framework dispatch layer. Two parallel communication systems exist for the same purpose. Should we bridge them?

## Assumptions

- A1: TermLink file/remote commands work reliably (NOT VALIDATED — never used in framework, only TermLink test suite)
- A2: Hub deployment is feasible (NOT VALIDATED — never attempted, requires process lifecycle management)
- A3: Bridge provides value over SSH dispatch (PARTIALLY VALIDATED — TermLink transport is superior but SSH works for current 2-machine topology)
- A4: Both sides need TermLink installed (VALIDATED — currently only on .112)

## Exploration Plan

1. Audit current fw dispatch implementation (done — SSH pipe with JSON envelopes)
2. Audit TermLink file/remote/hub capabilities (done — all exist, none wired to framework)
3. Evaluate 3 bridging options (done — file send, hub+remote, hybrid)
4. Assess infrastructure reality (done — hub never deployed, only 2 machines)
5. Make recommendation (done — DEFER)

## Technical Constraints

- TermLink hub requires a persistent process with lifecycle management
- Both communicating machines must have TermLink installed
- T-600 (attach-self) is prerequisite for remote session registration — still at inception
- Current topology is only 2 machines (.112 server, .107 Mac)

## Scope Fence

**IN:** Whether to bridge fw dispatch to TermLink's native transport.
**OUT:** Building the bridge (separate build task). TermLink Rust changes. Hub deployment.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (4 assumptions — 1 validated, 1 partial, 2 not validated)
- [x] Go/No-Go recommendation made (DEFER)

### Human
- [x] [REVIEW] Review exploration findings and approve defer decision
  **Steps:**
  1. Read `docs/reports/T-598-dispatch-termlink-bridge.md`
  2. Evaluate whether SSH dispatch limitations warrant the infrastructure cost of hub deployment
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-598 no-go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Discuss specific concerns about the recommendation

## Go/No-Go Criteria

**GO if:**
- 3+ machines need to communicate regularly
- SSH dispatch has hit concrete limitations (payload size, latency, reliability)
- T-600 (attach-self) is complete and TermLink deployed on remote machines

**NO-GO/DEFER if:**
- SSH dispatch works for current 2-machine topology (true)
- Hub infrastructure adds operational complexity without proportional benefit (true)
- Prerequisites (T-600 attach-self) are not ready (true)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** 3+ machines need to communicate regularly; SSH dispatch has hit concrete limitations (payload size, latency, reliability); T-600 (attach-self) is complete and TermLink deployed on remote machines; ...

## Decisions

**Decision**: GO

**Rationale**: 3+ machines need to communicate regularly; SSH dispatch has hit concrete limitations (payload size, latency, reliability); T-600 (attach-self) is complete and TermLink deployed on remote machines; ...

**Date**: 2026-03-28T17:08:25Z
## Decision

**Decision**: GO

**Rationale**: 3+ machines need to communicate regularly; SSH dispatch has hit concrete limitations (payload size, latency, reliability); T-600 (attach-self) is complete and TermLink deployed on remote machines; ...

**Date**: 2026-03-28T17:08:25Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-24T09:09:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T09:09:53Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-03-24T09:10:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T09:10:38Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: next → next

### 2026-03-24T09:13:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27 — artifact-reference [audit-fix]
- **Research artifact:** docs/reports/T-598-dispatch-termlink-bridge.md

### 2026-03-28T17:08:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 3+ machines need to communicate regularly; SSH dispatch has hit concrete limitations (payload size, latency, reliability); T-600 (attach-self) is complete and TermLink deployed on remote machines; ...

### 2026-03-28T17:08:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
