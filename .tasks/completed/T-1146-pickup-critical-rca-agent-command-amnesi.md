---
id: T-1146
name: "Pickup: CRITICAL RCA: Agent command amnesia has 3 structural root causes — framework scripts ARE the violation source (from 010-termlink)"
description: >
  Auto-created from pickup envelope. Source: 010-termlink, task T-972. Type: learning.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, learning]
components: []
related_tasks: []
created: 2026-04-12T10:12:02Z
last_update: 2026-04-13T07:36:21Z
date_finished: 2026-04-13T07:36:21Z
---

# T-1146: Pickup: CRITICAL RCA: Agent command amnesia has 3 structural root causes — framework scripts ARE the violation source (from 010-termlink)

## Problem Statement

Framework gate scripts (hooks, update-task, audit) output bare CLI commands as error messages ("run: fw inception decide..."). The agent relays these verbatim, violating PL-007 (always use `fw task review`, never dump commands). The framework itself is the source of the violation it's supposed to prevent. 40 bare command output sites identified across 7 files. See `docs/reports/T-1146-command-amnesia-rca.md`.

## Assumptions

- A1: Refactoring ~10 HIGH-severity sites (check-tier0.sh, update-task.sh) will eliminate the most visible PL-007 violations
- A2: RC-2 (ungoverned agent prose) is not fixable at framework level — requires Claude Code platform change
- A3: Partial fixes (T-1106, T-1141, T-1154) have already addressed some vectors but not the gate script output

## Exploration Plan

1. Scan all gate scripts for bare command output patterns — **DONE** (40 sites found)
2. Classify severity (HIGH/MEDIUM/LOW based on user-facing visibility) — **DONE**
3. Check what's already fixed by T-1106, T-1141, T-1154 — **DONE**
4. Propose targeted refactoring plan for HIGH sites — **DONE**

## Technical Constraints

- Claude Code has no `PreTextOutput` hook — agent prose is ungoverned
- Gate scripts run as PreToolUse hooks — their stderr is visible to the agent
- `bin/watchtower.sh` exists for port detection but is not used by most gate scripts

## Scope Fence

**IN scope:** RCA of bare command emission in gate scripts, severity classification, fix architecture, build task proposals.
**OUT of scope:** Actual refactoring of gate scripts (that's the build task). Claude Code platform changes for prose governance.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1146`
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- RCA identifies actionable root causes with concrete fix paths
- At least one HIGH-severity site can be refactored without breaking existing behavior
- The fix architecture is bounded (not a full rewrite)

**NO-GO if:**
- All bare command sites are already covered by PL-007 agent behavioral rule (no structural fix needed)
- The fix requires Claude Code platform changes we can't make

## Verification

# Research artifact exists
test -f docs/reports/T-1146-command-amnesia-rca.md

## Recommendation

**Recommendation:** GO — targeted refactoring of HIGH-severity gate script outputs.

**Rationale:** The RCA identifies 40 bare command output sites across 7 files. ~10 are HIGH-severity (check-tier0.sh, update-task.sh) — these produce the messages agents relay most often, causing recurring PL-007 violations. T-1141 codified PL-007 as a behavioral rule, but the framework itself violates it structurally. The fix is bounded: refactor gate script block messages to emit Watchtower URLs instead of CLI commands. Partially addressed by T-1154 (port detection helper) but not connected to gate scripts yet.

**Evidence:**
- 40 bare command output sites across 7 files (`docs/reports/T-1146-command-amnesia-rca.md`)
- Agent violated PL-007 within 3 minutes of building PL-007 (P-020 pickup from 010-termlink)
- T-1141 behavioral rule is insufficient — the framework scripts ARE the violation source
- RC-2 (ungoverned prose) is not fixable, so RC-1 and RC-3 fixes are the only path
- `bin/watchtower.sh` port detection already exists but isn't used by gate scripts

**Proposed build tasks (3):**
1. Refactor `check-tier0.sh` block message → emit Watchtower approval URL
2. Refactor `update-task.sh` guidance output → emit `fw task review` URLs
3. Connect `bin/watchtower.sh` port detection to gate script output

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — targeted refactoring of HIGH-severity gate script outputs.

Rationale: The RCA identifies 40 bare command output sites across 7 files. ~10 are HIGH-severity (check-tier0.sh, update-task.sh) — these produce the messages agents relay most often, causing recurring PL-007 violations. T-1141 codified PL-007 as a behavioral rule, but the framework itself violates it structurally. The fix is bounded: refactor gate script block messages to emit Watchtower URLs instead of CLI commands. Partially addressed by T-1154 (port detection helper) but not connected to gate scripts yet.

Evidence:
- 40 bare command output sites across 7 files (`docs/reports/T-1146-command-amnesia-rca.md`)
- Agent violated PL-007 within 3 minutes of building PL-007 (P-020 pickup from 010-termlink)
- T-1141 behavioral rule is insufficient — the framework scripts ARE the violation source
- RC-2 (ungoverned prose) is not fixable, so RC-1 and RC-3 fixes are the only path
- `bin/watchtower.sh` port detection already exists but isn't used by gate scripts

Proposed build tasks (3):
1. Refactor `check-tier0.sh` block message → emit Watchtower approval URL
2. Refactor `update-task.sh` guidance output → emit `fw task review` URLs
3. Connect `bin/watchtower.sh` port detection to gate script output

**Date**: 2026-04-13T07:36:21Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — targeted refactoring of HIGH-severity gate script outputs.

Rationale: The RCA identifies 40 bare command output sites across 7 files. ~10 are HIGH-severity (check-tier0.sh, update-task.sh) — these produce the messages agents relay most often, causing recurring PL-007 violations. T-1141 codified PL-007 as a behavioral rule, but the framework itself violates it structurally. The fix is bounded: refactor gate script block messages to emit Watchtower URLs instead of CLI commands. Partially addressed by T-1154 (port detection helper) but not connected to gate scripts yet.

Evidence:
- 40 bare command output sites across 7 files (`docs/reports/T-1146-command-amnesia-rca.md`)
- Agent violated PL-007 within 3 minutes of building PL-007 (P-020 pickup from 010-termlink)
- T-1141 behavioral rule is insufficient — the framework scripts ARE the violation source
- RC-2 (ungoverned prose) is not fixable, so RC-1 and RC-3 fixes are the only path
- `bin/watchtower.sh` port detection already exists but isn't used by gate scripts

Proposed build tasks (3):
1. Refactor `check-tier0.sh` block message → emit Watchtower approval URL
2. Refactor `update-task.sh` guidance output → emit `fw task review` URLs
3. Connect `bin/watchtower.sh` port detection to gate script output

**Date**: 2026-04-13T07:36:21Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T13:29:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T14:01:20Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-04-13T06:48:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-13T07:36:21Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — targeted refactoring of HIGH-severity gate script outputs.

Rationale: The RCA identifies 40 bare command output sites across 7 files. ~10 are HIGH-severity (check-tier0.sh, update-task.sh) — these produce the messages agents relay most often, causing recurring PL-007 violations. T-1141 codified PL-007 as a behavioral rule, but the framework itself violates it structurally. The fix is bounded: refactor gate script block messages to emit Watchtower URLs instead of CLI commands. Partially addressed by T-1154 (port detection helper) but not connected to gate scripts yet.

Evidence:
- 40 bare command output sites across 7 files (`docs/reports/T-1146-command-amnesia-rca.md`)
- Agent violated PL-007 within 3 minutes of building PL-007 (P-020 pickup from 010-termlink)
- T-1141 behavioral rule is insufficient — the framework scripts ARE the violation source
- RC-2 (ungoverned prose) is not fixable, so RC-1 and RC-3 fixes are the only path
- `bin/watchtower.sh` port detection already exists but isn't used by gate scripts

Proposed build tasks (3):
1. Refactor `check-tier0.sh` block message → emit Watchtower approval URL
2. Refactor `update-task.sh` guidance output → emit `fw task review` URLs
3. Connect `bin/watchtower.sh` port detection to gate script output

### 2026-04-13T07:36:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dced2dfe
- **Timestamp:** 2026-06-02T14:55:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
