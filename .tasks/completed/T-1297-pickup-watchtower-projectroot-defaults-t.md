---
id: T-1297
name: "Pickup: Watchtower PROJECT_ROOT defaults to FRAMEWORK_ROOT — ambient strip silently reads frameworks own state (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1123. Type: bug-report.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-18T15:21:34Z
last_update: 2026-04-22T05:19:22Z
date_finished: 2026-04-22T05:19:22Z
---

# T-1297: Pickup: Watchtower PROJECT_ROOT defaults to FRAMEWORK_ROOT — ambient strip silently reads frameworks own state (from termlink)

## Problem Statement

Duplicate of T-1303. Both cite termlink source T-1123 and describe the same `PROJECT_ROOT` fallback bug. Pickup dedup missed the collision. See `docs/reports/T-1297-duplicate-of-T-1303.md`.

## Assumptions

1. T-1303 exists with same source — TESTED TRUE (both cite termlink T-1123)
2. Work on both would be redundant — TESTED TRUE

## Exploration Plan

None — confirmed duplicate.

## Technical Constraints

None applicable.

## Scope Fence

**IN:** close this task as duplicate.
**OUT:** fixing the underlying PROJECT_ROOT fallback bug (handled under T-1303).

## Acceptance Criteria

### Agent
- [x] Problem statement validated (T-1297 cites termlink T-1123; T-1303 cites termlink T-1123)
- [x] Assumptions tested (duplicate confirmed by source-task ID)
- [x] Recommendation written with rationale (DEFER — close as duplicate; keep T-1303)

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

**Recommendation:** DEFER (duplicate of T-1303)

**Rationale:** Same termlink source (T-1123) and same bug-report as T-1303. Keeping both open creates confusion and splits effort. Close this task; keep T-1303 as canonical.

**Evidence:**
- T-1297 frontmatter: "Source: termlink, task T-1123. Type: bug-report."
- T-1303 frontmatter: "Source: termlink, task T-1123. Type: bug-report."
- Full note: `docs/reports/T-1297-duplicate-of-T-1303.md`

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

**Rationale**: Recommendation: DEFER (duplicate of T-1303)

Rationale: Same termlink source (T-1123) and same bug-report as T-1303. Keeping both open creates confusion and splits effort. Close this task; keep T-1303 as canonical.

Evidence:
- T-1297 frontmatter: "Source: termlink, task T-1123. Type: bug-report."
- T-1303 frontmatter: "Source: termlink, task T-1123. Type: bug-report."
- Full note: `docs/reports/T-1297-duplicate-of-T-1303.md`

**Date**: 2026-04-19T08:57:10Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-19T08:17:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-19T08:57:10Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER (duplicate of T-1303)

Rationale: Same termlink source (T-1123) and same bug-report as T-1303. Keeping both open creates confusion and splits effort. Close this task; keep T-1303 as canonical.

Evidence:
- T-1297 frontmatter: "Source: termlink, task T-1123. Type: bug-report."
- T-1303 frontmatter: "Source: termlink, task T-1123. Type: bug-report."
- Full note: `docs/reports/T-1297-duplicate-of-T-1303.md`

### 2026-04-22T05:19:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4f377c6b
- **Timestamp:** 2026-06-02T14:56:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
