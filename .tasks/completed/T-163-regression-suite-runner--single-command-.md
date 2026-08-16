---
id: T-163
name: "Regression suite runner — single command to validate framework health"
description: >
  Create fw test command that runs: ShellCheck on all .sh files, bats unit tests,
  bats integration tests, pytest web tests, test-tier0-patterns.py. Report: pass/fail/skip
  counts, coverage summary. Integrate with fw doctor (add test check). Consider pre-push
  hook integration. Ref: T-158

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
related_tasks: []
created: 2026-02-18T13:30:57Z
last_update: '2026-08-16T22:24:39Z'
date_finished: 2026-02-18T15:28:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-163: Regression suite runner — single command to validate framework health

## Context

T-159/T-160/T-161 built test infrastructure and tests. This task wires the single-command runner and doctor integration.

## Acceptance Criteria

- [x] `fw test` runs all suites (unit + integration + web) — done in T-159
- [x] `fw test unit` / `fw test integration` / `fw test web` / `fw test lint` — done in T-159
- [x] `fw doctor` reports test infrastructure status (bats count, shellcheck)
- [x] `fw test` help shows available sub-commands

## Verification

fw doctor 2>&1 | grep -q "Test infrastructure"
fw test unit
fw test help 2>&1 | grep -q "integration"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-02-18T13:30:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-163-regression-suite-runner--single-command-.md
- **Context:** Initial task creation

### 2026-02-18T15:28:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8b2f9c6a
- **Timestamp:** 2026-06-02T14:58:48Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `fw doctor 2>&1 | grep -q "Test infrastructure"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `fw test help 2>&1 | grep -q "integration"`
