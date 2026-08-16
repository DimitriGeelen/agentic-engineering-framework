---
id: T-792
name: "Pickup: TermLink agent dispatch pattern — cwd, timeout, worktree merge (from
  050-email-archive)"
description: >
  Auto-created from pickup envelope. Source: 050-email-archive, task T-400. Type:
  learning.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [pickup, learning]
components: [agents/termlink/termlink.sh]
related_tasks: []
created: 2026-03-30T14:51:26Z
last_update: '2026-08-16T22:25:39Z'
date_finished: 2026-04-04T20:50:34Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
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
  - ts: '2026-08-16T22:25:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-792: Pickup: TermLink agent dispatch pattern — cwd, timeout, worktree merge (from 050-email-archive)

## Problem Statement

`fw termlink dispatch` spawns Claude workers in `/tmp/tl-dispatch/<name>/`. Framework hooks fire on the first tool call and resolve PROJECT_ROOT by walking up from CWD. Since CWD is `/tmp/`, hooks either fail or find the wrong project. Three cascading failures: wrong project boundary, stale budget gate, wrong dispatch counter. Evidence: T-842 worker fully blocked, 3021-Bilderkarte agent hit sovereignty gate on stale inception.sh (T-857 fixed the version gap, but CWD remains broken).

Related: T-856 (human-owned inception for same problem), T-682 (TermLink --working-dir flag request).

## Assumptions

- A1: `tmux new-session -c <dir>` sets initial CWD for the shell inside the session
- A2: `claude -p` inherits CWD from the shell that launches it
- A3: Setting PROJECT_ROOT env var before launching claude worker propagates to hooks
- A4: The preamble `cd /opt/project` runs before any hook fires (DISPROVEN — hooks fire on first tool call before agent executes any commands)

## Exploration Plan

1. **Spike A**: Check if `tmux new-session -c <dir>` sets CWD → test with dispatch wrapper
2. **Spike B**: Check if `PROJECT_ROOT=X claude -p "..."` propagates to PreToolUse hooks
3. **Spike C**: Check current `fw termlink dispatch` implementation for CWD handling
4. **Evaluate**: Recommend fix based on findings

## Technical Constraints

- TermLink binary is external (github.com/DimitriGeelen/termlink) — binary changes go via T-682
- Framework-side workarounds (env vars, tmux -c) are faster to ship
- Workers must survive parent context compaction (T-818)

## Scope Fence

**IN scope:** Find a framework-side fix for worker CWD resolution
**OUT of scope:** TermLink binary modifications (deferred to T-682)

## Acceptance Criteria

### Agent
- [x] Problem statement validated (T-842 worker evidence analyzed, root cause: hooks resolve PROJECT_ROOT via git, env var bypass available)
- [x] Assumptions tested (A1-A3 validated, A4 disproven — see report)
- [x] Recommendation written with rationale (GO — export PROJECT_ROOT/FRAMEWORK_ROOT in run.sh)
- [x] Fix implemented in termlink.sh cmd_dispatch run.sh template

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
- Framework-side fix exists without TermLink binary changes
- Fix works for both framework repo and consumer projects

**NO-GO if:**
- All fixes require TermLink binary changes (defer to T-682)
- Fix introduces fragile hacks that break on path changes

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Framework-side fix proven, already implemented and propagated

**Date**: 2026-04-04T20:50:34Z

## Recommendation

**Recommendation:** GO
**Rationale:** Framework-side fix proven — export PROJECT_ROOT/FRAMEWORK_ROOT in dispatch run.sh. Zero TermLink binary changes, works for both framework repo and consumer projects, already implemented.
**Evidence:**
- T-842 worker analyzed: project resolved to wrong dir because hooks used git resolution
- lib/paths.sh line 33 already has env var guard: `if [[ -z "${PROJECT_ROOT:-}" ]]`
- Fix: 8 lines added to run.sh template in termlink.sh
- Research report: docs/reports/T-792-termlink-dispatch-cwd.md

## Decision

**Decision**: GO

**Rationale**: Framework-side fix proven, already implemented and propagated

**Date**: 2026-04-04T20:50:34Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-04T19:39:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-04T20:50:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Framework-side fix proven, already implemented and propagated

### 2026-04-04T20:50:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-02a9cafc
- **Timestamp:** 2026-06-02T15:04:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
