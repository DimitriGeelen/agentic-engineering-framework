---
id: T-1393
name: "Playwright test pollutes live decisions.yaml — add fixture to snapshot/restore"
description: >
  Playwright test pollutes live decisions.yaml — add fixture to snapshot/restore

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_api_context_capture.py]
related_tasks: []
created: 2026-04-23T12:14:00Z
last_update: 2026-04-23T12:18:49Z
date_finished: 2026-04-23T12:18:49Z
---

# T-1393: Playwright test pollutes live decisions.yaml — add fixture to snapshot/restore

## Context

`tests/playwright/test_api_context_capture.py` posts "Test decision from Playwright" and "Test learning from Playwright" through Watchtower's live API — the endpoints shell out to `fw context add-{decision,learning}` which write to the real `.context/project/{decisions,learnings}.yaml`. Each test run pollutes live data: D-004, D-005, D-007, D-008 (4 polluted decisions), 5 polluted learnings observed.

Root cause: Watchtower test server (port 3099) shares PROJECT_ROOT with the framework. Cleanest fix: per-class autouse fixture that snapshots both files and restores after each test.

## Acceptance Criteria

### Agent
- [x] Add autouse pytest fixture in `tests/playwright/test_api_context_capture.py` that snapshots `decisions.yaml` and `learnings.yaml` before each test and restores them after
- [x] Remove the 4 polluted "Test decision from Playwright" entries from `.context/project/decisions.yaml`
- [x] Remove the 5 polluted "Test learning from Playwright" entries from `.context/project/learnings.yaml`
- [x] Both YAML files still parse after cleanup
- [x] Running `pytest tests/playwright/test_api_context_capture.py` does NOT add new pollution entries (verified by diff)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

python3 -c "import yaml; yaml.safe_load(open('.context/project/decisions.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/project/learnings.yaml'))"
test $(grep -c "Test decision from Playwright" .context/project/decisions.yaml) -eq 0
test $(grep -c "Test learning from Playwright" .context/project/learnings.yaml) -eq 0
grep -q "_restore_project_state" tests/playwright/test_api_context_capture.py
grep -q "autouse=True" tests/playwright/test_api_context_capture.py

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

### 2026-04-23T12:14:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1393-playwright-test-pollutes-live-decisionsy.md
- **Context:** Initial task creation

### 2026-04-23T12:18:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-78d5f2b3
- **Timestamp:** 2026-06-02T14:57:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
