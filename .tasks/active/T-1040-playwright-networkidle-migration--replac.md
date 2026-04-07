---
id: T-1040
name: "Playwright networkidle migration — replace networkidle with domcontentloaded across 26 test files to fix 132 timeout failures"
description: >
  Playwright networkidle migration — replace networkidle with domcontentloaded across 26 test files to fix 132 timeout failures

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T15:13:51Z
last_update: 2026-04-07T15:13:51Z
date_finished: null
---

# T-1040: Playwright networkidle migration — replace networkidle with domcontentloaded across 26 test files to fix 132 timeout failures

## Context

Full Playwright suite (291 tests, 61 files) has 132 timeout failures. Root cause: `wait_for_load_state("networkidle")` times out under Flask's single-threaded dev server. Fix: replace all 102 occurrences across 26 files with `wait_for_load_state("domcontentloaded")`. T-1027 proved this fix works (3 instances in test_graduation.py).

## Acceptance Criteria

### Agent
- [ ] All `networkidle` references in tests/playwright/ replaced with `domcontentloaded`
- [ ] Zero occurrences of `networkidle` remain in tests/playwright/
- [ ] Playwright test collection succeeds (no import/syntax errors)

## Verification

# No networkidle references remain
cd /opt/999-Agentic-Engineering-Framework && test $(grep -r "networkidle" tests/playwright/ | wc -l) -eq 0
# Test collection succeeds
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/ --collect-only -q 2>&1 | tail -1 | grep -q "test"

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

### 2026-04-07T15:13:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1040-playwright-networkidle-migration--replac.md
- **Context:** Initial task creation
