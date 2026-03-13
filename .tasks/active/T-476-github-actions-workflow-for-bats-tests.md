---
id: T-476
name: "GitHub Actions workflow for bats tests"
description: >
  Create .github/workflows/test.yml running bats tests on push/PR. Install bats-core via npm. Run fw test. Phase 3 of T-473 GO.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [testing, D2, ci]
components: []
related_tasks: []
created: 2026-03-12T21:31:06Z
last_update: 2026-03-13T07:35:56Z
date_finished: null
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
- [ ] [RUBBER-STAMP] Verify workflow runs on GitHub after next push
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
