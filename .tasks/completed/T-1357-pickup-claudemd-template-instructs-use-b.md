---
id: T-1357
name: "Pickup: CLAUDE.md template instructs Use bin/fw not fw — correct in framework repo, broken for consumer projects (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1156. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-20T13:47:01Z
last_update: 2026-04-22T09:37:38Z
date_finished: 2026-04-22T09:37:38Z
source_task_id_in_origin: T-1156
source_project_in_origin: "termlink"
---

# T-1357: Pickup: CLAUDE.md template instructs Use bin/fw not fw — correct in framework repo, broken for consumer projects (from termlink)

## Problem Statement

Pickup reports CLAUDE.md template instructs "use `bin/fw`" without distinguishing between framework repo (where `bin/fw` is correct) and consumer projects (where it's `.agentic-framework/bin/fw`). This is **already fixed** by T-1257 (completed 2026-04-18) which added the context-aware `fw` path rule to CLAUDE.md §Copy-Pasteable Commands.

## Assumptions

1. T-1257 addresses this specific issue — TRUE (CLAUDE.md §Copy-Pasteable Commands now distinguishes framework repo vs consumer)
2. Pickup was created before T-1257 landed — TRUE (pickup created 2026-04-20; T-1257 completed 2026-04-18)
3. Stale pickup with no remaining scope — TRUE

## Exploration Plan

None — pre-fix confirmed by reading CLAUDE.md §Copy-Pasteable Commands and `.tasks/completed/T-1257*`.

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
- [x] Problem statement validated (CLAUDE.md §Copy-Pasteable Commands rule #3 + #4 distinguish framework-repo vs consumer)
- [x] Assumptions tested (T-1257 pre-dates pickup creation)
- [x] Recommendation written with rationale (DEFER — already fixed)

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

**Recommendation:** DEFER (already fixed)

**Rationale:** T-1257 completed 2026-04-18 added the context-aware `fw` path rule to CLAUDE.md §Copy-Pasteable Commands: "Framework repo: use `bin/fw`. Consumer project: use `.agentic-framework/bin/fw`." The pickup was created 2026-04-20, 2 days after the fix landed — stale pickup, no remaining scope.

**Evidence:**
- `.tasks/completed/T-1257-fix-context-blind-fw-path-rule-in-claude.md` — completed 2026-04-18
- CLAUDE.md §Copy-Pasteable Commands rules #3-#4 (framework repo vs consumer path distinction)
- L-237 pattern: grep completed tasks for the concern before scoping — this inception is itself an application of L-237

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

**Decision**: DEFER (already fixed by T-1257)

**Rationale**: Pickup stale — T-1257 landed the fix 2 days before pickup was created. CLAUDE.md §Copy-Pasteable Commands already distinguishes framework repo vs consumer path.

**Date**: 2026-04-22T08:30:00Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-22T09:37:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-22T09:37:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
