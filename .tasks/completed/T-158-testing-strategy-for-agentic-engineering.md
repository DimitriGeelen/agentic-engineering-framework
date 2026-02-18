---
id: T-158
name: "Testing strategy for Agentic Engineering Framework"
description: >
  Inception: Testing strategy for Agentic Engineering Framework

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
related_tasks: [T-159, T-160, T-161, T-162, T-163]
created: 2026-02-18T12:52:24Z
last_update: 2026-02-18T13:30:10Z
date_finished: 2026-02-18T13:30:10Z
---

# T-158: Testing strategy for Agentic Engineering Framework

## Problem Statement

The Agentic Engineering Framework has **10,182 lines of bash** and **5,375 lines of Python** with near-zero automated test coverage. 5 critical-path enforcement scripts (budget-gate, check-active-task, check-tier0, checkpoint, error-watchdog) have **0 tests**. 8 of 10 historical bugs were preventable by automated tests. The framework enforces testing discipline on tasks (P-011 verification gate) but has no regression suite for itself. This violates Constitutional Directives D1 (antifragility) and D2 (reliability).

## Assumptions

- A1: bats (Bash Automated Testing System) is suitable for bash unit/integration tests — VALIDATED (industry standard)
- A2: 59% of bash code rated HARD to test can be improved with light refactoring — VALIDATED (extract pure logic pattern)
- A3: Existing web tests (test_app.py, test_scan.py) provide a foundation to extend — VALIDATED (38 routes covered)

## Exploration Plan

Three parallel audits completed (reports in .context/research/):
1. Bash script inventory + testability rating → `.context/research/T-158-bash-audit.md`
2. Web UI route/endpoint audit → `.context/research/T-158-web-audit.md`
3. Hook/gate inventory + historical bug analysis → `.context/research/T-158-hooks-and-bugs.md`

### Key Findings
- **44 bash scripts**, 10,182 LOC: 10 EASY (23%), 18 MEDIUM (41%), 16 HARD (36%)
- **59% of LOC** is tightly coupled side effects (HARD category)
- **38 web routes**, 26 templates, 5,375 LOC Python
- **Existing tests**: test-tier0-patterns.py (47 tests), test_app.py (38 tests), test_scan.py
- **10 historical bugs** found; **8/10 preventable** by automated tests
- **5 critical-path hooks** (budget-gate, check-active-task, check-tier0, checkpoint, error-watchdog) — **0 tests**

### Spawned Build Tasks
- T-159: Test infrastructure — bats framework, test runner, `fw test` command
- T-160: Bash unit tests — 10 EASY scripts (pure logic, 569 LOC)
- T-161: Hook/gate integration tests — 5 critical enforcement scripts
- T-162: Web edge case tests — subprocess timeouts, error parsing, malformed YAML
- T-163: Regression suite runner — single `fw test` command

## Technical Constraints

- Bash testing: bats framework (apt-get install bats or git clone)
- Python testing: pytest (already used in test_app.py)
- No CI/CD currently — tests must be runnable via `fw test` or `fw doctor`
- Hook scripts must be testable in isolation (mock JSONL transcripts, mock git repos)

## Scope Fence

**IN scope:** Test infrastructure, bash unit tests, hook/gate integration tests, web edge case tests, regression runner
**OUT of scope:** Performance testing, load testing, browser E2E testing (Playwright/Selenium), UI visual regression

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Evidence of preventable bugs (found 8/10)
- Critical path scripts untested (found 5/5 untested)

**NO-GO if:**
- Existing test coverage is adequate (it is not — 0% bash, 70% web routes)
- Testing adds no value given usage-based validation (8 bugs disprove this)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

### 2026-02-18 — Testing Strategy GO/NO-GO
- **Chose:** GO — implement structured testing across the framework
- **Why:** 8/10 historical bugs preventable, 0% critical path coverage, directives D1+D2 demand it
- **Rejected:** Status quo (usage-based validation only) — survivorship bias, no regression prevention

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-18T13:29:10Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Overwhelming evidence: 10,182 LOC bash with 0% unit test coverage, 5 critical-path enforcement scripts untested, 8/10 historical bugs preventable by tests. Framework's own directives (antifragility, reliability) demand this. Web UI has foundation (38 route tests) but bash layer is completely exposed.

### 2026-02-18T13:30:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
