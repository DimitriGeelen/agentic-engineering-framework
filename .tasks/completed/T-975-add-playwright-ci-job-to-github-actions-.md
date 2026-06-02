---
id: T-975
name: "Add Playwright CI job to GitHub Actions test workflow"
description: >
  Add Playwright CI job to GitHub Actions test workflow

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T20:33:20Z
last_update: 2026-04-06T20:35:34Z
date_finished: 2026-04-06T20:35:34Z
---

# T-975: Add Playwright CI job to GitHub Actions test workflow

## Context

T-968 CI integration. `.github/workflows/test.yml` has `bats` and `e2e` jobs but no Playwright job. Add one.

## Acceptance Criteria

### Agent
- [x] Playwright job added to `.github/workflows/test.yml`
- [x] Job installs Python deps (flask, playwright, pytest) and Chromium via `playwright install chromium --with-deps`
- [x] Job runs `python3 -m pytest tests/playwright/ -v` (conftest.py auto-starts server)
- [x] YAML is valid
- [x] Verification commands pass

## Verification

grep -q 'playwright' .github/workflows/test.yml
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

### 2026-04-06T20:33:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-975-add-playwright-ci-job-to-github-actions-.md
- **Context:** Initial task creation

### 2026-04-06T20:35:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Playwright CI job added to GitHub Actions

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e239002e
- **Timestamp:** 2026-06-02T15:06:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
