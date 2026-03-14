---
id: T-492
name: "Build E2E onboarding test script — install → init → doctor → serve → smoke"
description: >
  From T-489 GO. Build a test script that validates the complete onboarding path in a temp directory. Fix: (1) fw doctor exit code always 0 bug, (2) preflight non-blocking in init, (3) doctor doesn't check Flask. Script: create temp dir, git init, fw init, fw doctor (expect exit 0), start Watchtower on :9877, run smoke_test.py --port 9877, cleanup. Output JSON summary. Target: <2 minutes, CI-friendly.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [testing, onboarding, ci]
components: []
related_tasks: []
created: 2026-03-14T17:05:26Z
last_update: 2026-03-14T17:05:26Z
date_finished: null
---

# T-492: Build E2E onboarding test script — install → init → doctor → serve → smoke

## Context

E2E onboarding test validates the complete path from `fw init` through `fw doctor` to Watchtower serving.
Research: `docs/reports/T-489-onboarding-test-inception.md` (5 untested seams, 17 failure modes).
Terminal experiments: `docs/reports/T-490-self-test-inception.md` (6/6 passed).

## Acceptance Criteria

### Agent
- [x] `tests/e2e/onboarding-test.sh` exists and is executable
- [x] Script creates temp dir, git init, runs fw init, validates artifacts
- [x] Script runs fw doctor and checks exit code
- [x] Script starts Watchtower on test port, runs smoke_test.py, checks results
- [x] Script produces JSON summary on stdout with `--json` flag
- [x] Script cleans up temp dir on exit (trap)
- [x] Script exits 0 on success, non-zero on failure
- [x] `fw self-test` route in bin/fw calls the script
- [x] Script completes in under 60 seconds

### Human
- [ ] [RUBBER-STAMP] Run `fw self-test` from project root and verify it passes
  **Steps:**
  1. Run `fw self-test` in terminal
  2. Watch output — each phase should show PASS/FAIL
  **Expected:** All phases pass, exit code 0
  **If not:** Note which phase failed and the error message

## Verification

# Full test: ./bin/fw self-test onboarding (runs 5 phases, ~15s)
test -x tests/e2e/onboarding-test.sh
grep -q "self-test" bin/fw
grep -q "onboarding" tests/e2e/onboarding-test.sh

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

### 2026-03-14T17:05:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-492-build-e2e-onboarding-test-script--instal.md
- **Context:** Initial task creation
