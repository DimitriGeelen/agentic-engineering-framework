---
id: T-331
name: "Build GitHub Action for fw audit in CI/CD"
description: >
  Create action.yml + Dockerfile for GitHub Actions marketplace. Enables teams to run fw audit as a CI/CD gate on PRs. High discovery channel for compliance-minded teams. Ref: docs/reports/T-327-visibility-strategy.md

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-05T01:12:37Z
last_update: 2026-03-10T22:04:13Z
date_finished: 2026-03-05T01:31:31Z
---

# T-331: Build GitHub Action for fw audit in CI/CD

## Context

GitHub Action for running `fw audit` in CI/CD pipelines. Ref: `docs/reports/T-327-visibility-strategy.md`

## Acceptance Criteria

### Agent
- [x] action.yml exists at repo root with proper GitHub Action metadata
- [x] Composite action with install + audit steps
- [x] Example workflow file provided (.github/workflows/example-audit.yml)
- [x] README documents the action usage

### Human
- [ ] [REVIEW] Action works when tested in a real GitHub Actions workflow
  **Steps:**
  1. In a GitHub repo that uses the framework, add `.github/workflows/audit.yml` using the example at `.github/workflows/example-audit.yml`
  2. Push a commit or trigger the workflow manually via Actions tab
  3. Check the workflow run log in GitHub Actions
  **Expected:** Workflow completes green; `fw audit` output visible in logs with PASS/WARN/FAIL counts
  **If not:** Check the action log for installation errors or missing dependencies

## Verification

test -f action.yml
test -f .github/workflows/example-audit.yml
grep -q "runs:" action.yml
grep -q "fw audit" action.yml

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

### 2026-03-05T01:12:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-331-build-github-action-for-fw-audit-in-cicd.md
- **Context:** Initial task creation

### 2026-03-05T01:27:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-05T01:31:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:13Z — status-update [task-update-agent]
- **Change:** horizon: now → next
