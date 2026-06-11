---
id: T-1296
name: "Pickup: Watchtower CSRF 403 after restart — auto-regenerated FW_SECRET_KEY
  + multi-process leak (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1125. Type: bug-report.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-18T15:21:28Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-22T05:19:19Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1296: Pickup: Watchtower CSRF 403 after restart — auto-regenerated FW_SECRET_KEY + multi-process leak (from termlink)

## Problem Statement

Duplicate of T-1302. Both tasks cite the same termlink source (T-1125) and the same bug report about Watchtower Flask `secret_key` auto-regeneration breaking CSRF. Pickup dedup missed the collision. See `docs/reports/T-1296-duplicate-of-T-1302.md`.

## Assumptions

1. T-1302 exists with same source — TESTED TRUE (both cite termlink T-1125)
2. Work on both would be redundant — TESTED TRUE

## Exploration Plan

None — confirmed duplicate via source-task-ID cross-check.

## Technical Constraints

None applicable.

## Scope Fence

**IN:** close this task as duplicate.
**OUT:** fixing the underlying CSRF bug (handled under T-1302).

## Acceptance Criteria

### Agent
- [x] Problem statement validated (T-1296 cites termlink T-1125; T-1302 cites termlink T-1125)
- [x] Assumptions tested (duplicate confirmed by source-task ID)
- [x] Recommendation written with rationale (DEFER — close as duplicate; keep T-1302)

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

**Recommendation:** DEFER (duplicate of T-1302)

**Rationale:** Same termlink source (T-1125) and same bug-report as T-1302. T-1302 is already in the triage pipeline. Keeping both open creates confusion and splits effort. Close this task; keep T-1302 as the canonical record.

**Evidence:**
- T-1296 frontmatter: "Source: termlink, task T-1125. Type: bug-report."
- T-1302 frontmatter: "Source: termlink, task T-1125. Type: bug-report."
- Both titles reference the same CSRF / secret_key regeneration issue
- Full note: `docs/reports/T-1296-duplicate-of-T-1302.md`

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

**Rationale**: Recommendation: DEFER (duplicate of T-1302)

Rationale: Same termlink source (T-1125) and same bug-report as T-1302. T-1302 is already in the triage pipeline. Keeping both open creates confusion and splits effort. Close this task; keep T-1302 as the canonical record.

Evidence:
- T-1296 frontmatter: "Source: termlink, task T-1125. Type: bug-report."
- T-1302 frontmatter: "Source: termlink, task T-1125. Type: bug-report."
- Both titles reference the same CSRF / secret_key regeneration issue
- Full note: `docs/reports/T-1296-duplicate-of-T-1302.md`

**Date**: 2026-04-19T08:57:05Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-19T08:15:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-19T08:57:05Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER (duplicate of T-1302)

Rationale: Same termlink source (T-1125) and same bug-report as T-1302. T-1302 is already in the triage pipeline. Keeping both open creates confusion and splits effort. Close this task; keep T-1302 as the canonical record.

Evidence:
- T-1296 frontmatter: "Source: termlink, task T-1125. Type: bug-report."
- T-1302 frontmatter: "Source: termlink, task T-1125. Type: bug-report."
- Both titles reference the same CSRF / secret_key regeneration issue
- Full note: `docs/reports/T-1296-duplicate-of-T-1302.md`

### 2026-04-22T05:19:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-128707f9
- **Timestamp:** 2026-06-02T14:56:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
