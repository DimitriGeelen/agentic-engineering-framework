---
id: T-1145
name: "Pickup: P-010: RCA on recurring assumption fabrication/retraction/correction-of-retraction cycle — 4 proposed structural remediations (R1 provenance schema, R2 negative-claim TTL, R3 post-compact quarantine, R4 cross-section consistency) (from ring20-dashboard)"
description: >
  Auto-created from pickup envelope. Source: ring20-dashboard, task T-011. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, feature-proposal]
components: []
related_tasks: []
created: 2026-04-12T10:11:59Z
last_update: 2026-04-22T08:10:42Z
date_finished: 2026-04-22T08:10:42Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1145: Pickup: P-010: RCA on recurring assumption fabrication/retraction/correction-of-retraction cycle — 4 proposed structural remediations (R1 provenance schema, R2 negative-claim TTL, R3 post-compact quarantine, R4 cross-section consistency) (from ring20-dashboard)

## Problem Statement

Agents cycle through contradictory truth states about assumptions across sessions (fact→retracted→re-instated). No framework gate catches the contradiction. Observed in ring20-dashboard T-011 with A-007 across 3 sessions. Root cause: 5-layer failure from wrong grep to no provenance schema. See `docs/reports/T-1145-assumption-provenance-rca.md`.

## Assumptions

- A1: This is the first documented instance across 980+ tasks — may be rare
- A2: Behavioral mitigation (verify before retraction) may be sufficient
- A3: Structural fixes (R1-R4) cost 20-30 hours total — only warranted if pattern recurs

## Exploration Plan

1. Analyze pickup envelope P-010 — DONE
2. Classify 5-layer root cause — DONE
3. Evaluate 4 proposed remediations — DONE
4. Monitor for recurrence frequency before committing to build

## Technical Constraints

Assumption provenance would require schema extension to `fw assumption` CLI and Watchtower display.

## Scope Fence

**IN:** RCA, remediation evaluation, monitoring recommendation.
**OUT:** Building any of R1-R4 (deferred pending recurrence evidence).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1145`
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Pattern recurs >1/month across projects after 30-day monitoring
- Cross-machine coordination creates frequent assumption state conflicts

**NO-GO if:**
- First documented instance in 980+ tasks and monitoring shows <1/month
- Behavioral mitigations (verify before retraction) are sufficient

**DEFER if (RECOMMENDED):**
- Insufficient data on recurrence frequency — need 30-day monitoring window

## Verification

# Research artifact exists
test -f docs/reports/T-1145-assumption-provenance-rca.md

## Recommendation

**Recommendation:** DEFER — pending 30-day recurrence monitoring.

**Rationale:** The 5-layer RCA is thorough but based on a single observed instance. 4 remediations proposed (R1-R4) cost 20-30 hours total. Before investing, we need recurrence data. First documented instance in 980+ completed tasks suggests rarity.

**Evidence:**
- Single observed instance: ring20-dashboard T-011, A-007, across 3 sessions
- 5-layer root cause from tactical (wrong grep) to structural (no provenance schema)
- 4 remediations evaluated: R1 (provenance schema), R2 (negative-claim TTL), R3 (post-compact quarantine), R4 (cross-section consistency)
- Cost estimate: 20-30 hours for all 4 remediations
- 980+ completed tasks, first documented assumption contradiction cycle

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

**Rationale**: Recommendation: DEFER — pending 30-day recurrence monitoring.

Rationale: The 5-layer RCA is thorough but based on a single observed instance. 4 remediations proposed (R1-R4) cost 20-30 hours total. Before investing, we need recurrence data. First documented instance in 980+ completed tasks suggests rarity.

Evidence:
- Single observed instance: ring20-dashboard T-011, A-007, across 3 sessions
- 5-layer root cause from tactical (wrong grep) to structural (no provenance schema)
- 4 remediations evaluated: R1 (provenance schema), R2 (negative-claim TTL), R3 (post-compact quarantine), R4 (cross-section consistency)
- Cost estimate: 20-30 hours for all 4 remediations
- 980+ completed tasks, first documented assumption contradiction cycle

**Date**: 2026-04-13T11:06:59Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T13:58:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T14:01:20Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-04-13T11:06:59Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER — pending 30-day recurrence monitoring.

Rationale: The 5-layer RCA is thorough but based on a single observed instance. 4 remediations proposed (R1-R4) cost 20-30 hours total. Before investing, we need recurrence data. First documented instance in 980+ completed tasks suggests rarity.

Evidence:
- Single observed instance: ring20-dashboard T-011, A-007, across 3 sessions
- 5-layer root cause from tactical (wrong grep) to structural (no provenance schema)
- 4 remediations evaluated: R1 (provenance schema), R2 (negative-claim TTL), R3 (post-compact quarantine), R4 (cross-section consistency)
- Cost estimate: 20-30 hours for all 4 remediations
- 980+ completed tasks, first documented assumption contradiction cycle

### 2026-04-22T08:10:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-22T08:10:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-15793ba8
- **Timestamp:** 2026-06-02T14:55:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
