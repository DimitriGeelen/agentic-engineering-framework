---
id: T-818
name: "TermLink dispatch result persistence — ensure worker outputs survive parent budget exhaustion"
description: >
  Inception: TermLink dispatch result persistence — ensure worker outputs survive parent budget exhaustion

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-03T21:27:24Z
last_update: 2026-04-13T06:23:27Z
date_finished: 2026-04-03T21:36:04Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-818: TermLink dispatch result persistence — ensure worker outputs survive parent budget exhaustion

## Problem Statement

When TermLink workers are dispatched in parallel, their results follow the "write to /tmp, return path + summary" convention. But if the parent session hits budget critical before integrating results, the output sits in `/tmp/` (ephemeral) instead of the tracked repo. Real incident: T-816 worker wrote 307-line analysis to `/tmp/fw-agent-T-816-null-object-fallback.md` but `docs/reports/T-816-null-object-fallback.md` only had the 9-line skeleton. Recovered manually next session.

**For whom:** Any session dispatching TermLink workers near budget boundaries.
**Why now:** First real data loss incident from this gap.

## Assumptions

- A1: Workers currently write to /tmp because the dispatch preamble instructs them to
- A2: Workers could write directly to target files in the repo instead
- A3: A handover-time sweep of /tmp/fw-agent-* could catch orphaned outputs
- A4: The budget gate allows writes to .context/ paths — a bus post would survive

## Exploration Plan

1. Audit current dispatch preamble instructions for output paths
2. Evaluate 3 options: direct-write, bus post, handover sweep
3. Assess interaction with budget gate (which paths are allowed at critical)
4. Recommend approach

## Technical Constraints

- Budget gate blocks Write/Edit to source files at critical level
- Budget gate ALLOWS writes to `.context/`, `.tasks/`, `.claude/`
- `/tmp/` files survive within a session but may be cleaned between sessions
- TermLink workers run in independent processes (not subject to parent budget gate)

## Scope Fence

**IN:** Fix the "worker output lost when parent budget exhausted" gap
**OUT:** General TermLink dispatch improvements, worker monitoring, result format changes

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- A fix prevents worker output loss without adding significant complexity
- The fix works within existing budget gate constraints

**NO-GO if:**
- The only fix requires changing Claude Code's hook semantics
- The problem is too rare to justify structural changes (< 1 incident per 50 sessions)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: simple fix, workers write to target files directly

**Date**: 2026-04-03T21:36:04Z

## Recommendation

- **Recommendation:** GO
- **Rationale:** Simple fix — TermLink workers should write to target files directly (not `/tmp/`). Update dispatch preamble with TermLink-specific section (~10 lines). Add handover orphan check as defense-in-depth (~5 lines). Zero architecture change, backward compatible.
- **Evidence:**
  - T-816 incident: 307 lines lost to `/tmp/`, recovered manually
  - Root cause: dispatch preamble designed for Task tool agents (shared context), not TermLink workers (independent processes)
  - Full analysis: `docs/reports/T-818-termlink-dispatch-persistence.md`

## Decision

**Decision**: GO

**Rationale**: simple fix, workers write to target files directly

**Date**: 2026-04-03T21:36:04Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-03T21:28:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-03T21:36:04Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** simple fix, workers write to target files directly

### 2026-04-03T21:36:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b867f1e7
- **Timestamp:** 2026-06-02T15:05:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
