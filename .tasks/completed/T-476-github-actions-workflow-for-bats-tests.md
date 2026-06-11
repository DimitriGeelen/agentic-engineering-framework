---
id: T-476
name: "GitHub Actions workflow for bats tests"
description: >
  Create .github/workflows/test.yml running bats tests on push/PR. Install bats-core
  via npm. Run fw test. Phase 3 of T-473 GO.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [testing, D2, ci]
components: []
related_tasks: []
created: 2026-03-12T21:31:06Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-13T07:37:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
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
---

# T-476: GitHub Actions workflow for bats tests

## Context

Phase 3 of T-473 GO. `fw test` already runs bats locally. Need a GitHub Actions workflow for CI.

## Acceptance Criteria

### Agent
- [x] `.github/workflows/test.yml` exists with valid YAML
- [x] Workflow triggers on push and pull_request
- [x] Workflow installs bats-core and Python 3
- [x] Workflow runs `bats tests/integration/ tests/unit/`
- [x] Workflow runs on ubuntu-latest

### Human
- [x] [RUBBER-STAMP] Verify workflow runs on GitHub after next push
  **Steps:**
  1. Push to GitHub: `git push origin master`
  2. Go to repository → Actions tab
  3. Check that "Test" workflow appears and runs
  **Expected:** Green checkmark, all 187 tests pass
  **If not:** Check the workflow log for install or path issues

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

### 2026-03-12T21:31:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-476-github-actions-workflow-for-bats-tests.md
- **Context:** Initial task creation

### 2026-03-13T07:35:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-13T07:37:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:17Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8cc85d77
- **Timestamp:** 2026-06-02T15:03:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
