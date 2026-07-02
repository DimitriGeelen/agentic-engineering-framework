---
id: T-159
name: "Test infrastructure — bats framework, test runner, fw test command"
description: >
  Install bats (Bash Automated Testing System). Create tests/ directory structure
  (unit/, integration/, fixtures/, mocks/). Add fw test command that runs all tests
  (bats + pytest). Add ShellCheck linting. Ref: T-158 inception, /tmp/T-158-bash-audit.md

status: work-completed
workflow_type: build
owner: agent
horizon: null
related_tasks: []
created: 2026-02-18T13:30:27Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-02-18T15:11:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-159: Test infrastructure — bats framework, test runner, fw test command

## Context

T-158 inception GO: 44 bash scripts (10,182 LOC), zero test framework. Audit at `/tmp/T-158-bash-audit.md`.

## Acceptance Criteria

- [x] bats-core installed and functional (`bats --version`)
- [x] `tests/` directory structure: `unit/`, `integration/`, `fixtures/`
- [x] `tests/test_helper.bash` with common setup (FRAMEWORK_ROOT, temp dirs, cleanup)
- [x] At least 1 sample unit test passes (`bats tests/unit/`)
- [x] `fw test` command runs all bats tests and reports results
- [x] ShellCheck installed and functional (`shellcheck --version`)
- [x] `fw test --lint` runs ShellCheck on all framework `.sh` files

## Verification

bats --version
shellcheck --version
bats tests/unit/
fw test unit
test -d tests/unit && test -d tests/integration && test -d tests/fixtures

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

### 2026-02-18T13:30:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-159-test-infrastructure--bats-framework-test.md
- **Context:** Initial task creation

### 2026-02-18T13:59:20Z — status-update [task-update-agent]
- **Change:** horizon: now → later

### 2026-02-18T15:11:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bd50157c
- **Timestamp:** 2026-06-02T14:58:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#3 (ACs)** — `tests/test_helper.bash` with common setup (FRAMEWORK_ROOT, temp dirs, cleanup)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/test_helper.bash in: `tests/test_helper.bash` with common setup (FRAMEWORK_ROOT, temp dirs, cleanup)`

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/`
