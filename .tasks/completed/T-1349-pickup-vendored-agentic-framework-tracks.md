---
id: T-1349
name: "Pickup: Vendored .agentic-framework/ tracks Python __pycache__ files — Uncommitted changes present is the #1 audit trend (23×) for consumers (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1130. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-20T07:46:35Z
last_update: 2026-04-22T09:36:24Z
date_finished: 2026-04-22T09:36:24Z
---

# T-1349: Pickup: Vendored .agentic-framework/ tracks Python __pycache__ files — Uncommitted changes present is the #1 audit trend (23×) for consumers (from termlink)

## Problem Statement

Duplicate of T-1321 (canonical). Both cite termlink source T-1130 (bug report: Vendored .agentic-framework/ tracks __pycache__). Pickup dedup missed the collision. No new information.

## Assumptions

1. T-1321 exists with same termlink source — TRUE
2. No new information here — TRUE

## Exploration Plan

None — confirmed duplicate via source-task-ID cross-check.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated (T-1349 cites termlink T-1130; T-1321 cites termlink T-1130)
- [x] Assumptions tested (duplicate confirmed by source-task ID)
- [x] Recommendation written with rationale (DEFER — close as duplicate; keep T-1321)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (close as duplicate)

**Rationale:** T-1349 and T-1321 both cite termlink source task T-1130. Working this task would be redundant.

**Evidence:**
- T-1349 source: termlink T-1130
- T-1321 source: termlink T-1130 (canonical target)
- Pickup dedup missed the collision (G-046 class)

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

**Decision**: DEFER (duplicate of T-1321)

**Rationale**: Same termlink source task (T-1130) as T-1321. No independent research value.

**Date**: 2026-04-22T08:28:00Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-22T09:36:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-22T09:36:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-503286a8
- **Timestamp:** 2026-06-02T14:56:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
