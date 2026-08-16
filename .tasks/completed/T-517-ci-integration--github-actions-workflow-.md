---
id: T-517
name: "CI integration — GitHub Actions workflow for E2E Tier A tests"
description: >
  Add GitHub Actions workflow that runs Tier A E2E tests on push. Requires termlink
  binary in CI (cargo install or pre-built). Tier B tests manual trigger only (API
  cost). From T-513 inception build task 4.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [testing, ci, D2]
components: []
related_tasks: []
created: 2026-03-17T21:10:45Z
last_update: '2026-08-16T22:25:32Z'
date_finished: 2026-03-17T22:03:37Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:23Z'
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
  - ts: '2026-08-16T22:25:32Z'
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

# T-517: CI integration — GitHub Actions workflow for E2E Tier A tests

## Context

Add E2E Tier A tests to the existing GitHub Actions CI. Tier B is manual-only (API cost).

## Acceptance Criteria

### Agent
- [x] GitHub Actions workflow file updated with E2E job
- [x] Workflow installs TermLink via cargo
- [x] Tier A tests run automatically on push/PR
- [x] YAML validates cleanly

### Human
- [x] [RUBBER-STAMP] Verify workflow runs on GitHub after next push
  **Steps:**
  1. Push to GitHub
  2. Check Actions tab for "Test" workflow
  3. Verify e2e job appears alongside bats job
  **Expected:** Both jobs run, e2e job passes or shows clear failures
  **If not:** Check workflow logs for TermLink install issues

## Verification

python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))"

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

### 2026-03-17T21:10:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-517-ci-integration--github-actions-workflow-.md
- **Context:** Initial task creation

### 2026-03-17T22:01:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-17T22:03:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3b53f704
- **Timestamp:** 2026-06-02T15:03:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
