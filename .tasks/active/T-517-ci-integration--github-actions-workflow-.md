---
id: T-517
name: "CI integration — GitHub Actions workflow for E2E Tier A tests"
description: >
  Add GitHub Actions workflow that runs Tier A E2E tests on push. Requires termlink binary in CI (cargo install or pre-built). Tier B tests manual trigger only (API cost). From T-513 inception build task 4.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [testing, ci, D2]
components: []
related_tasks: []
created: 2026-03-17T21:10:45Z
last_update: 2026-03-17T22:01:59Z
date_finished: null
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
- [ ] [RUBBER-STAMP] Verify workflow runs on GitHub after next push
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
