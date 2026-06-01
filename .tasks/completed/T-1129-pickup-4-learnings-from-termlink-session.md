---
id: T-1129
name: "Pickup: 4 learnings from termlink session — subagent scope violation, format assumptions, stale gaps, dog-fooding (from 010-termlink)"
description: >
  Auto-created from pickup envelope. Source: 010-termlink, task T-944. Type: learning.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, learning]
components: []
related_tasks: []
created: 2026-04-12T08:45:02Z
last_update: 2026-04-13T07:35:42Z
date_finished: 2026-04-13T07:35:42Z
---

# T-1129: Pickup: 4 learnings from termlink session — subagent scope violation, format assumptions, stale gaps, dog-fooding (from 010-termlink)

## Problem Statement

4 learnings from 010-termlink session (T-944) need evaluation and capture: PL-003 (subagent scope violation), PL-004 (format convention), PL-005 (stale gaps auto-closure), PL-006 (dog-food Watchtower).

## Assumptions

- A1: All 4 learnings are actionable and worth capturing
- A2: Some already have structural fixes from prior tasks (T-1119/T-1120 for PL-006)

## Exploration Plan

1. Read pickup envelope P-012 — DONE
2. Capture all 4 as learnings — DONE (L-002 through L-005)
3. Assess structural fix needs — PL-003 needs post-dispatch diff check (future build), PL-005 needs auto-close audit check (future build)

## Technical Constraints

No platform constraints — knowledge capture task.

## Scope Fence

**IN:** Capture learnings. **OUT:** Building structural fixes.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1129`
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Learnings capture recurring patterns that affected multiple sessions
- At least one learning warrants a structural fix (not just behavioral)

**NO-GO if:**
- All learnings are already codified in CLAUDE.md behavioral rules
- No structural fix is warranted

## Verification

# All 4 learnings captured in learnings.yaml
bash -c 'grep -c "T-1129" .context/project/learnings.yaml | grep -q "[4-9]"'

## Recommendation

**Recommendation:** GO — all 4 learnings captured, 2 warrant structural fixes.

**Rationale:** All 4 learnings from the 010-termlink session address recurring patterns. PL-003 (subagent scope violation — corrupted 6 files) and PL-005 (stale gaps auto-closure) warrant structural enforcement. PL-004 (format convention) and PL-006 (dog-food features) are behavioral learnings already captured.

**Evidence:**
- PL-003: 6 task files corrupted by scope-violating subagent in a single session. Captured as L-002. Structural fix: post-dispatch diff check.
- PL-004: Agent generated .md when framework expects .yaml. Captured as L-005. Behavioral learning, no structural fix needed.
- PL-005: G-001/G-002/G-003 stayed "watching" for days after fixes shipped. Captured as L-003. Structural fix: audit check for resolved gaps.
- PL-006: Approvals page had 3 compound bugs caught by first real use. Captured as L-004. Already addressed by T-1119/T-1120.

**Proposed build tasks:** Two structural fixes — post-dispatch diff check, auto-close resolved gaps in audit.

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — all 4 learnings captured, 2 warrant structural fixes.

Rationale: All 4 learnings from the 010-termlink session address recurring patterns. PL-003 (subagent scope violation — corrupted 6 files) and PL-005 (stale gaps auto-closure) warrant structural enforcement. PL-004 (format convention) and PL-006 (dog-food features) are behavioral learnings already captured.

Evidence:
- PL-003: 6 task files corrupted by scope-violating subagent in a single session. Captured as L-002. Structural fix: post-dispatch diff check.
- PL-004: Agent generated .md when framework expects .yaml. Captured as L-005. Behavioral learning, no structural fix needed.
- PL-005: G-001/G-002/G-003 stayed "watching" for days after fixes shipped. Captured as L-003. Structural fix: audit check for resolved gaps.
- PL-006: Approvals page had 3 compound bugs caught by first real use. Captured as L-004. Already addressed by T-1119/T-1120.

Proposed build tasks: Two structural fixes — post-dispatch diff check, auto-close resolved gaps in audit.

**Date**: 2026-04-13T07:34:54Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — all 4 learnings captured, 2 warrant structural fixes.

Rationale: All 4 learnings from the 010-termlink session address recurring patterns. PL-003 (subagent scope violation — corrupted 6 files) and PL-005 (stale gaps auto-closure) warrant structural enforcement. PL-004 (format convention) and PL-006 (dog-food features) are behavioral learnings already captured.

Evidence:
- PL-003: 6 task files corrupted by scope-violating subagent in a single session. Captured as L-002. Structural fix: post-dispatch diff check.
- PL-004: Agent generated .md when framework expects .yaml. Captured as L-005. Behavioral learning, no structural fix needed.
- PL-005: G-001/G-002/G-003 stayed "watching" for days after fixes shipped. Captured as L-003. Structural fix: audit check for resolved gaps.
- PL-006: Approvals page had 3 compound bugs caught by first real use. Captured as L-004. Already addressed by T-1119/T-1120.

Proposed build tasks: Two structural fixes — post-dispatch diff check, auto-close resolved gaps in audit.

**Date**: 2026-04-13T07:34:54Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T13:45:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T14:01:21Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-04-13T06:46:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-13T07:34:49Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — all 4 learnings captured, 2 warrant structural fixes.

Rationale: All 4 learnings from the 010-termlink session address recurring patterns. PL-003 (subagent scope violation — corrupted 6 files) and PL-005 (stale gaps auto-closure) warrant structural enforcement. PL-004 (format convention) and PL-006 (dog-food features) are behavioral learnings already captured.

Evidence:
- PL-003: 6 task files corrupted by scope-violating subagent in a single session. Captured as L-002. Structural fix: post-dispatch diff check.
- PL-004: Agent generated .md when framework expects .yaml. Captured as L-005. Behavioral learning, no structural fix needed.
- PL-005: G-001/G-002/G-003 stayed "watching" for days after fixes shipped. Captured as L-003. Structural fix: audit check for resolved gaps.
- PL-006: Approvals page had 3 compound bugs caught by first real use. Captured as L-004. Already addressed by T-1119/T-1120.

Proposed build tasks: Two structural fixes — post-dispatch diff check, auto-close resolved gaps in audit.

### 2026-04-13T07:34:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — all 4 learnings captured, 2 warrant structural fixes.

Rationale: All 4 learnings from the 010-termlink session address recurring patterns. PL-003 (subagent scope violation — corrupted 6 files) and PL-005 (stale gaps auto-closure) warrant structural enforcement. PL-004 (format convention) and PL-006 (dog-food features) are behavioral learnings already captured.

Evidence:
- PL-003: 6 task files corrupted by scope-violating subagent in a single session. Captured as L-002. Structural fix: post-dispatch diff check.
- PL-004: Agent generated .md when framework expects .yaml. Captured as L-005. Behavioral learning, no structural fix needed.
- PL-005: G-001/G-002/G-003 stayed "watching" for days after fixes shipped. Captured as L-003. Structural fix: audit check for resolved gaps.
- PL-006: Approvals page had 3 compound bugs caught by first real use. Captured as L-004. Already addressed by T-1119/T-1120.

Proposed build tasks: Two structural fixes — post-dispatch diff check, auto-close resolved gaps in audit.

### 2026-04-13T07:35:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
