---
id: T-491
name: "Build fw self-test command — phases 1-5 with JSON output and CI integration"
description: >
  From T-490 GO. Build agents/self-test/self-test.sh with 5 phases: (1) preflight — deps, temp project; (2) gate validation — Tier 0/1/2 via exit codes; (3) task lifecycle — create/update/complete; (4) Watchtower — start on :9877, poll health, run smoke_test.py; (5) cleanup + JSON report. Also fix fw doctor exit code bug (always returns 0). Key constraints: all lifecycle in single chained commands (shell state doesn't persist), sleep 4 for Flask startup, pipe JSON to stdin for hook scripts.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [testing, self-test, ci]
components: []
related_tasks: []
created: 2026-03-14T17:05:01Z
last_update: 2026-03-14T17:05:54Z
date_finished: null
---

# T-491: Build fw self-test command — phases 1-5 with JSON output and CI integration

## Context

Extends `fw self-test` from T-492 (onboarding only) to cover enforcement gates and task lifecycle.
Research: `docs/reports/T-490-self-test-inception.md` (6/6 experiments passed).

## Acceptance Criteria

### Agent
- [x] `tests/e2e/gates-test.sh` exists — tests task gate, Tier 0 gate via exit codes
- [x] `tests/e2e/lifecycle-test.sh` exists — creates/updates/completes task in temp project
- [x] `fw self-test` orchestrates all phases (onboarding + gates + lifecycle)
- [x] `fw self-test --json` produces combined JSON with all phase results
- [x] Each phase script is independently runnable
- [x] All phases pass on the current framework

### Human
- [ ] [RUBBER-STAMP] Run `fw self-test` and verify all phases pass
  **Steps:**
  1. Run `./bin/fw self-test` from framework root
  2. Watch output — each phase shows PASS/FAIL
  **Expected:** All phases pass, exit code 0
  **If not:** Note which phase failed

## Verification

bash tests/e2e/gates-test.sh --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['failed']==0, f'Gate tests failed: {d}'"
bash tests/e2e/lifecycle-test.sh --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['failed']==0, f'Lifecycle tests failed: {d}'"
test -x tests/e2e/gates-test.sh
test -x tests/e2e/lifecycle-test.sh

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

### 2026-03-14T17:05:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-491-build-fw-self-test-command--phases-1-5-w.md
- **Context:** Initial task creation
