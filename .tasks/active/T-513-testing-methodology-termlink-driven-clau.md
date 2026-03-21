---
id: T-513
name: "Testing methodology: TermLink-driven Claude Code E2E framework validation"
description: >
  Design a testing methodology and step-by-step workflow that uses TermLink to spawn
  and orchestrate Claude Code sessions for automated end-to-end testing of framework
  installations. Existing tests (bats, fw self-test, fw doctor) validate shell mechanics —
  this validates the full agent experience: does Claude Code, governed by the framework,
  actually work correctly through task lifecycle, hook enforcement, and session management?

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [testing, termlink, e2e, quality, D2]
components: [agents/termlink/termlink.sh, bin/fw]
related_tasks: [T-491, T-492, T-502, T-503, T-473, T-476]
created: 2026-03-17T20:26:00Z
last_update: 2026-03-17T21:09:58Z
date_finished: 2026-03-17T21:09:58Z
---

# T-513: Testing methodology: TermLink-driven Claude Code E2E framework validation

## Problem Statement

The framework has four layers of testing today:

1. **`fw doctor`** — Static health checks (files exist, tools installed, config valid)
2. **`fw self-test`** — Mechanical shell commands (create task, commit, audit)
3. **Bats tests** — Unit tests for bash enforcement scripts (T-473/T-476)
4. **Pre-push audit** — 99 compliance checks before every push

All four test the framework's *shell mechanics*. None test the framework's *agent governance* — whether Claude Code, running under CLAUDE.md rules with hooks active, actually behaves correctly through real workflows.

**The gap:** A user installs the framework, starts Claude Code, and says "create a task and fix a bug." Does the task gate fire? Do commits include task references? Does the budget gate warn at 60%? Does handover generate correctly? We don't know — no test exercises this path.

**Why now:** TermLink (T-502/T-503) now provides the primitives to programmatically spawn, control, and observe Claude Code sessions. `tl-claude.sh` can start/stop sessions. `termlink interact` can send commands and read output. `termlink pty inject/output` can feed prompts and capture responses. The building blocks exist.

**For whom:** Framework maintainers (validate releases before pushing), external adopters (verify installation works), CI/CD (automated regression after changes).

## Assumptions

- A1: Claude Code can be meaningfully tested via TermLink session injection (`pty inject` + `pty output`)
- A2: API costs for E2E tests are acceptable (each test scenario = N API calls)
- A3: Tests can be made deterministic enough to assert pass/fail (Claude responses vary)
- A4: `termlink interact` provides sufficient structured output for assertions
- A5: A test can complete within a reasonable time-box (< 5 min per scenario)
- A6: The testing methodology can work with both real API calls and potentially mocked/cached responses

## Exploration Plan

| # | Spike | Time-box | Deliverable |
|---|-------|----------|-------------|
| 1 | **Primitives audit:** What TermLink commands can we use for test orchestration? What's reliable for scripted interaction with Claude Code? | 30min | Primitives matrix (command → reliability → use case) |
| 2 | **Scenario catalog:** What agent behaviors should we test? Map framework governance claims to testable scenarios. | 30min | Scenario list with expected behaviors |
| 3 | **Assertion strategy:** How do we verify Claude Code did the right thing? File existence, git log, command output, or TermLink output parsing? | 20min | Assertion patterns per scenario type |
| 4 | **Proof of concept:** Run one simple scenario end-to-end (spawn Claude, inject prompt, verify task created) | 30min | Working script or evidence of feasibility/blockers |
| 5 | **Workflow design:** How should tests be structured, run, and reported? Script format, CI integration, cost management. | 20min | Proposed workflow + test runner design |
| 6 | **Decomposition:** Carve into build tasks | 15min | Task list with dependencies |

## Technical Constraints

- TermLink requires a spawn backend (terminal, tmux, or background PTY)
- Claude Code needs API key (ANTHROPIC_API_KEY) — tests incur real API costs
- Claude Code responses are non-deterministic — assertions must check outcomes (files, git state) not exact text
- `termlink pty inject` is fire-and-forget — no synchronous response. Must poll `pty output` or use `termlink event wait`
- Session startup has latency (~3-5s for Claude Code to load CLAUDE.md and hooks)
- Hooks snapshot at session start — test framework must ensure hooks are installed before spawning
- CI environments may not have tmux — background PTY backend needed as fallback

## Scope Fence

**IN scope:**
- Testing methodology design (what to test, how to test, how to assert)
- Workflow design (script structure, runner, reporting)
- TermLink primitives evaluation for test orchestration
- Proof of concept for one scenario
- Cost estimation for running the test suite
- CI integration approach

**OUT of scope:**
- Building the full test suite (post-GO build tasks)
- Mock/stub framework for avoiding API costs (future optimization)
- Performance/load testing
- Testing TermLink itself (that's TermLink's own test suite)
- Testing on non-Linux platforms (future scope)

## Acceptance Criteria

### Agent
- [x] TermLink primitives audited for test orchestration reliability
- [x] Scenario catalog produced (framework governance → testable behavior)
- [x] Assertion strategy defined per scenario type
- [x] Proof of concept attempted (1 scenario: spawn → prompt → verify)
- [x] Workflow design documented (runner, CI, cost model)
- [x] Research artifact at `docs/reports/T-513-termlink-testing-methodology.md`
- [x] Go/No-Go decision recorded

### Human
- [ ] [REVIEW] Review methodology and approve testing approach
  **Steps:**
  1. Read `docs/reports/T-513-termlink-testing-methodology.md`
  2. Assess: are the right scenarios being tested?
  3. Assess: is the API cost model acceptable?
  4. Decide: approve, adjust scope, or defer
  **Expected:** Clear direction on testing methodology before building
  **If not:** Note specific concerns for iteration

## Go/No-Go Criteria

**GO if:**
- TermLink primitives reliably control Claude Code sessions (proof of concept works)
- At least 5 meaningful governance scenarios are testable
- Assertion strategy produces deterministic pass/fail (not flaky)
- API cost per full test run is < $5
- Tests can run in CI (no GUI dependency)

**NO-GO if:**
- TermLink interaction with Claude Code is too unreliable for scripted testing
- Claude non-determinism makes assertions consistently flaky
- API cost is prohibitive for routine testing
- Spawn/inject latency makes test suite impractically slow (> 30min for basic suite)

## Verification

test -f docs/reports/T-513-termlink-testing-methodology.md

## Decisions

**Decision**: GO

**Rationale**: TermLink primitives validated live (spawn+interact <1s, structured JSON). Two-tier approach: Tier A (12 shell-level tests, $0) covers enforcement gates, Tier B (4 agent tests, ~$2-4) covers full lifecycle. 4 build tasks.

**Date**: 2026-03-17T21:09:58Z
## Decision

**Decision**: GO

**Rationale**: TermLink primitives validated live (spawn+interact <1s, structured JSON). Two-tier approach: Tier A (12 shell-level tests, $0) covers enforcement gates, Tier B (4 agent tests, ~$2-4) covers full lifecycle. 4 build tasks.

**Date**: 2026-03-17T21:09:58Z

## Updates

### 2026-03-17T20:26:00Z — task-created [task-create-agent]
- **Action:** Created inception task from human request
- **Context:** User wants to leverage TermLink's new Claude Code session management
  (tl-claude.sh, termlink interact/inject/output) to build automated E2E tests
  that validate framework governance works correctly with a real Claude Code agent.

### 2026-03-17T20:44:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** TermLink primitives validated live (spawn+interact <1s, structured JSON). Two-tier approach: Tier A (12 shell-level tests, $0) covers enforcement gates, Tier B (4 agent tests, ~$2-4) covers full lifecycle. Outcome-based assertions avoid nondeterminism. 4 build tasks.

### 2026-03-17T21:06:30Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-03-17T21:06:35Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** TermLink primitives validated live (spawn+interact <1s, structured JSON). Two-tier approach: Tier A (12 shell-level tests, $0) covers enforcement gates, Tier B (4 agent tests, ~$2-4) covers full lifecycle. 4 build tasks.

### 2026-03-17T21:09:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** TermLink primitives validated live (spawn+interact <1s, structured JSON). Two-tier approach: Tier A (12 shell-level tests, $0) covers enforcement gates, Tier B (4 agent tests, ~$2-4) covers full lifecycle. 4 build tasks.

### 2026-03-17T21:09:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
