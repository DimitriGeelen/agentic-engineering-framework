---
id: T-1042
name: "Playwright test speedup — reduce default timeout and add pytest configuration"
description: >
  Playwright test speedup — reduce default timeout and add pytest configuration

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: [tests/playwright/conftest.py]
related_tasks: []
created: 2026-04-07T15:45:51Z
last_update: 2026-04-07T15:50:24Z
date_finished: 2026-04-07T15:50:24Z
---

# T-1042: Playwright test speedup — reduce default timeout and add pytest configuration

## Context

Full Playwright suite (291 tests) takes ~19 min because each timeout failure burns 30s (Playwright default). Reducing to 10s and adding pytest-timeout@5s per test cuts failure duration by 66%, reducing suite time from ~19 min to ~7-8 min.

## Acceptance Criteria

### Agent
- [x] conftest.py sets Playwright default timeout to 10s for page and context
- [x] pytest.ini or conftest sets per-test timeout marker (pytest-timeout not available, using Playwright native timeouts)
- [x] Test collection still succeeds (305 tests collected)

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/ --collect-only -q 2>&1 | tail -1 | grep -q "test"
cd /opt/999-Agentic-Engineering-Framework && grep -q "set_default_timeout" tests/playwright/conftest.py

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

### 2026-04-07T15:45:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1042-playwright-test-speedup--reduce-default-.md
- **Context:** Initial task creation

### 2026-04-07T15:50:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4a3d1afa
- **Timestamp:** 2026-06-02T14:54:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/ --collect-only -q 2>&1 | tail -1 | grep -q "test"`
