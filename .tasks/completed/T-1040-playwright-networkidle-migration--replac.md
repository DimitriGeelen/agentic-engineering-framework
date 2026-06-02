---
id: T-1040
name: "Playwright networkidle migration — replace networkidle with domcontentloaded across 26 test files to fix 132 timeout failures"
description: >
  Playwright networkidle migration — replace networkidle with domcontentloaded across 26 test files to fix 132 timeout failures

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_approvals.py, tests/playwright/test_assumptions.py, tests/playwright/test_cockpit.py, tests/playwright/test_config.py, tests/playwright/test_core.py, tests/playwright/test_costs.py, tests/playwright/test_cron.py, tests/playwright/test_directives.py, tests/playwright/test_discoveries.py, tests/playwright/test_discovery.py, tests/playwright/test_docs.py, tests/playwright/test_enforcement.py, tests/playwright/test_fabric.py, tests/playwright/test_inception.py, tests/playwright/test_metrics.py, tests/playwright/test_patterns.py, tests/playwright/test_project.py, tests/playwright/test_quality.py, tests/playwright/test_review.py, tests/playwright/test_risks.py, tests/playwright/test_search.py, tests/playwright/test_sessions.py, tests/playwright/test_smoke.py, tests/playwright/test_tasks.py, tests/playwright/test_terminal.py, tests/playwright/test_timeline.py]
related_tasks: []
created: 2026-04-07T15:13:51Z
last_update: 2026-04-07T16:37:09Z
date_finished: 2026-04-07T16:37:09Z
---

# T-1040: Playwright networkidle migration — replace networkidle with domcontentloaded across 26 test files to fix 132 timeout failures

## Context

Full Playwright suite (291 tests, 61 files) has 132 timeout failures. Root cause: `wait_for_load_state("networkidle")` times out under Flask's single-threaded dev server. Fix: replace all 102 occurrences across 26 files with `wait_for_load_state("domcontentloaded")`. T-1027 proved this fix works (3 instances in test_graduation.py).

## Acceptance Criteria

### Agent
- [x] All `networkidle` references in tests/playwright/ replaced with `domcontentloaded` (102 occurrences across 26 files)
- [x] Zero occurrences of `networkidle` remain in tests/playwright/
- [x] Playwright test collection succeeds (305 tests, no errors)

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

### 2026-04-07T16:37:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-71064b94
- **Timestamp:** 2026-06-02T14:54:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/ --collect-only -q 2>&1 | tail -1 | grep -q "test"`
