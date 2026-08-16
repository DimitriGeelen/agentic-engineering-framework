---
id: T-317
name: "Build fw test-onboarding CLI script (8 checkpoints)"
description: >
  Build agents/onboarding-test/test-onboarding.sh — deterministic script that creates
  temp project, runs fw init, exercises 8 checkpoints (scaffold, hooks, first task,
  task gate, first commit, audit, self-audit, handover), captures structured PASS/WARN/FAIL
  output. Wire into bin/fw as 'fw test-onboarding'. No fw dependency (standalone).
  From T-307 GO decision.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-03-04T21:20:46Z
last_update: '2026-08-16T22:25:27Z'
date_finished: 2026-03-04T21:37:17Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-317: Build fw test-onboarding CLI script (8 checkpoints)

## Context

From T-307 inception GO decision. See `docs/reports/T-307-hybrid-onboarding-test.md`.

## Acceptance Criteria

### Agent
- [x] `agents/onboarding-test/test-onboarding.sh` exists and is executable
- [x] Script runs standalone (no fw dependency — finds own root via script location)
- [x] 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover
- [x] PASS/WARN/FAIL/SKIP output per checkpoint with summary counts
- [x] Exit code: 0=pass, 1=warnings, 2=failures
- [x] Cascading skip: failed checkpoint causes dependent checkpoints to skip
- [x] `fw test-onboarding` routes to the script
- [x] Supports `--keep` (preserve target dir), `--quiet` (no color), custom target dir
- [x] All 8 checkpoints pass on current framework (27/27 PASS)

## Verification

bash -n agents/onboarding-test/test-onboarding.sh
test -x agents/onboarding-test/test-onboarding.sh
agents/onboarding-test/test-onboarding.sh 2>&1 | grep -q "SUMMARY"
agents/onboarding-test/test-onboarding.sh 2>&1 | grep -q "ONBOARDING CLEAN"
grep -q "test-onboarding" bin/fw

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

### 2026-03-04T21:20:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-317-build-fw-test-onboarding-cli-script-8-ch.md
- **Context:** Initial task creation

### 2026-03-04T21:37:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-61c0038b
- **Timestamp:** 2026-06-02T15:02:07Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `agents/onboarding-test/test-onboarding.sh 2>&1 | grep -q "SUMMARY"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `agents/onboarding-test/test-onboarding.sh 2>&1 | grep -q "ONBOARDING CLEAN"`
