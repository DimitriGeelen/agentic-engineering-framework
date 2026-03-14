---
id: T-489
name: "End-to-end onboarding test — validate fresh install → init → serve → smoke across platforms"
description: >
  Inception: End-to-end onboarding test — validate fresh install → init → serve → smoke across platforms

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-14T16:53:43Z
last_update: 2026-03-14T17:03:52Z
date_finished: 2026-03-14T17:03:52Z
---

# T-489: End-to-end onboarding test — validate fresh install → init → serve → smoke across platforms

## Problem Statement

No automated test validates the complete onboarding path: `curl | bash` install → `fw init` in a fresh project → `fw serve` starts Watchtower → smoke tests pass → `fw doctor` reports healthy. Each piece is tested in isolation (install.sh works, smoke_test.py works, fw doctor works) but nobody tests them together. macOS field testing (T-481, T-483) proved the pieces break at the seams — file permissions, Python version compat, missing seeds.

For whom: Framework developers (catch regressions), new users (confidence the install works), CI/CD (gate releases).

Why now: We're approaching external launch (T-334). First impressions depend on install working first time.

## Assumptions

- A1: A complete onboarding test can run in a temp directory without affecting the host system
- A2: `fw init` + `fw serve` can work in an isolated test environment (no global state dependency beyond ~/.agentic-framework)
- A3: The test can complete in under 5 minutes (CI-friendly)
- A4: Cross-platform differences (macOS/Linux) can be detected and handled in a single test script

## Exploration Plan

### Spike 1: Map the onboarding surface (30min)
Trace every step from `curl | bash` to "framework is working". Document each file created, each command run, each dependency checked. Identify failure points.

### Spike 2: Existing test assets audit (30min)
What already exists? `agents/onboarding-test/test-onboarding.sh`, `web/smoke_test.py`, `fw doctor`, install.sh's self-test. What can be composed vs. what's missing?

## Technical Constraints

- Must work on macOS (Homebrew Python 3.9+) and Linux (apt Python 3.10+)
- Must not require root/sudo
- Must clean up after itself (temp dirs, background processes)
- Watchtower start must timeout gracefully if port is in use
- Must handle missing optional deps (Ollama, bats, shellcheck) without failing

## Scope Fence

**IN:** Install → init → serve → smoke → doctor in a temp directory. Cross-platform script. CI integration design.
**OUT:** Multi-user testing. Network/firewall testing. Ollama integration testing. Performance benchmarks.

## Acceptance Criteria

- [x] Complete onboarding path mapped (every step, every file, every failure point)
- [x] Existing test assets inventoried and composability assessed
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- The onboarding path has ≥3 untested seams (points where isolated tests don't cover the integration)
- A single script can orchestrate the full path in <5 minutes
- Existing assets (smoke_test.py, fw doctor, test-onboarding.sh) can be composed without major refactoring

**NO-GO if:**
- The onboarding path is already adequately covered by existing tests
- Cross-platform differences require platform-specific test suites (too much effort)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 5 untested integration seams, 17 failure modes (7 untested), fw doctor exit code bug. E2E test feasible.

**Date**: 2026-03-14T17:03:52Z
## Decision

**Decision**: GO

**Rationale**: 5 untested integration seams, 17 failure modes (7 untested), fw doctor exit code bug. E2E test feasible.

**Date**: 2026-03-14T17:03:52Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-14T17:02:57Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5 untested integration seams, 17 failure modes (7 untested), fw doctor exit code bug, Flask not checked by doctor. E2E test script is feasible and high-value.

### 2026-03-14T17:03:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5 untested integration seams, 17 failure modes (7 untested), fw doctor exit code bug, Flask not checked by doctor. E2E test is feasible — existing smoke_test.py + fw doctor + init can be composed.

### 2026-03-14T17:03:14Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-03-14T17:03:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5 untested integration seams, 17 failure modes (7 untested), fw doctor exit code bug. E2E test is feasible — compose existing smoke_test.py + fw doctor + init into single script.

### 2026-03-14T17:03:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5 untested integration seams, 17 failure modes (7 untested), fw doctor exit code bug. E2E test feasible — compose smoke_test.py + fw doctor + init.

### 2026-03-14T17:03:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5 untested integration seams, 17 failure modes (7 untested), fw doctor exit code bug. E2E test feasible.

### 2026-03-14T17:03:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
