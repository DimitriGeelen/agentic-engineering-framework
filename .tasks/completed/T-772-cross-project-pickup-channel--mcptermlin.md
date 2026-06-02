---
id: T-772
name: "Cross-project pickup channel — MCP/TermLink-based push for learnings, bugfixes, feature proposals"
description: >
  Inception: Cross-project pickup channel — MCP/TermLink-based push for learnings, bugfixes, feature proposals

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: [T-469, T-598, T-682, T-704]
created: 2026-03-30T12:45:22Z
last_update: 2026-04-06T22:29:22Z
date_finished: 2026-03-30T13:08:54Z
---

# T-772: Cross-project pickup channel — MCP/TermLink-based push for learnings, bugfixes, feature proposals

## Problem Statement

Cross-project knowledge sharing is currently pull-based: the framework agent runs `fw harvest` to extract learnings from consumer projects. There is no structured way for a consumer project's agent to **push** a bug fix, learning, or feature proposal back to the framework. Pickup messages exist but are unstructured text blobs with no schema, no intake flow, and governance gaps (T-469).

**For whom:** Framework maintainer (Dimitri) and consumer project agents.
**Why now:** TermLink + MCP infrastructure is in place. Multiple consumer projects exist. Cross-project learnings are being lost because harvest requires the framework agent to initiate.

## Assumptions

- A1: Consumer projects encounter framework bugs/patterns worth sharing back
- A2: TermLink hub connectivity is reliable enough for structured message passing
- A3: MCP tool exposure gives better discoverability than raw TermLink commands
- A4: Incoming proposals should always create inception tasks (never direct builds — T-469 lesson)

## Exploration Plan

1. **TermLink feasibility spike** — Use TermLink hub to send a structured JSON payload from .107 consumer project to framework agent. Validate round-trip. (30 min)
2. **Schema design** — Define pickup envelope types: `bug-report`, `learning`, `feature-proposal`, `pattern`. Map each to an intake flow (inception task, learning capture, etc.). (30 min)
3. **MCP tool design** — Design `fw-pickup-receive` MCP tool signature. Evaluate if it should be a skill, an MCP tool, or a `fw pickup` CLI command (or all three). (20 min)
4. **Governance model** — How incoming pickups are triaged. Auto-create inception? Require human approval? Dedup against existing tasks? (20 min)

## Technical Constraints

- TermLink hub must be reachable from consumer projects (currently .107 → .112 hub → framework)
- MCP server must be running for MCP-based intake
- Pickup payloads must be small enough for TermLink message passing (< 10KB)
- Framework agent may not be running when pickup arrives — need persistent queue

## Scope Fence

**IN scope:**
- Receive mechanism (how pickups arrive at the framework)
- Pickup schema (what fields, what types)
- Intake governance (what happens after arrival)
- MCP tool exposure design

**OUT of scope:**
- Building the full implementation (that's a build task after GO)
- Multi-hop routing (project A → project B → framework)
- Bidirectional sync (framework → consumer push-back)

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (especially A2 — TermLink round-trip)
- [x] Schema draft documented
- [x] MCP tool signature designed
- [x] Governance model proposed
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact at `docs/reports/T-772-cross-project-pickup.md`
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-772 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- TermLink round-trip works reliably for structured payloads
- Schema covers the 3 primary use cases (bug, learning, feature)
- Governance model prevents T-469-class bypass (pickup → build without scoping)

**NO-GO if:**
- TermLink connectivity too fragile for structured intake
- Complexity exceeds value (fw harvest already covers most cases)
- No real demand from consumer projects (assumption A1 fails)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Deterministic pipeline with local+TermLink transport. Evidence: pickup-051-vinix24 has 6 unprocessed issues.             
  Steelman/strawman analysis completed by 3 research agents.

**Date**: 2026-03-30T13:08:54Z

## Recommendation

**GO** — Build a deterministic cross-project pickup pipeline.

**Rationale:**
- pickup-051-vinix24 proves demand (6 issues, 2 HIGH bugs, zero processed)
- Harvest is pull-only and reactive — fails when consumer finds urgent framework bug
- fw bus was never used because it had no intake pipeline — T-772 IS the pipeline
- Both transports (local + TermLink) share the same processing backend

**Evidence:**
- Steelman agent: T-549, T-679, pickup-051-vinix24 all show knowledge trapped in consumer projects
- Strawman agent: Valid risk (bus v2 trap) — mitigated by processing existing observations on day 1
- Patterns agent: Observation inbox exists but has zero automation; harvest works but is pull-only

**Build tasks to create after GO:**
1. `fw pickup receive` — intake pipeline (parse envelope, dedup, create inception, notify)
2. `fw pickup send` — consumer-side CLI (serialize + write to inbox or termlink remote push)
3. `fw pickup process` — cron-triggered inbox scanner (deterministic, idempotent)
4. Observation inbox migration — process existing pickup-051-vinix24 through the pipeline
5. TermLink transport variant — `fw pickup send --remote hub-addr` using `termlink remote push`

## Decision

**Decision**: GO

**Rationale**: Deterministic pipeline with local+TermLink transport. Evidence: pickup-051-vinix24 has 6 unprocessed issues.             
  Steelman/strawman analysis completed by 3 research agents.

**Date**: 2026-03-30T13:08:54Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-30T12:50:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-30T13:08:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Deterministic pipeline with local+TermLink transport. Evidence: pickup-051-vinix24 has 6 unprocessed issues.             
  Steelman/strawman analysis completed by 3 research agents.

### 2026-03-30T13:08:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fa135525
- **Timestamp:** 2026-06-02T15:04:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`
