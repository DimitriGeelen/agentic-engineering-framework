---
id: T-968
name: "Codify 3-tier test approach for AC verification — programmatic, TermLink E2E,
  Playwright regression"
description: >
  The framework has rules (CLAUDE.md §AC Classification, §Verification Tiers) but
  no tooling
  enforcement. 127 bats tests exist for Tier 1, but zero Playwright tests and zero
  TermLink E2E
  tests. Human ACs pile up (110+ unchecked) because functional checks that could be
  automated
  are written as Human ACs instead. This inception researches how to close the gap
  between
  the rules and the infrastructure — fw test command, tests/playwright/ directory,
  CI integration,
  AC-to-test conversion pipeline.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [testing, governance, infrastructure]
components: []
related_tasks: [T-954, T-823, T-516, T-158]
created: 2026-04-06T19:21:20Z
last_update: '2026-08-16T22:25:44Z'
date_finished: 2026-04-06T19:37:23Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-968: Codify 3-tier test approach for AC verification — programmatic, TermLink E2E, Playwright regression

## Problem Statement

CLAUDE.md defines a 3-tier verification model (T-954):
- **Tier 1 (programmatic):** Shell commands, curl, grep — 127 bats tests exist
- **Tier 2 (TermLink E2E):** Spawn process, inject commands, check output — **zero tests**
- **Tier 3 (Playwright):** Browser automation for UI verification — **zero tests**

The rules exist but the infrastructure doesn't. Result: functional UI checks are written as Human ACs (because "no Playwright test runner exists"), creating an ever-growing backlog (110+ unchecked Human ACs). When the human DOES verify them, the test is ephemeral — no regression coverage.

**The gap:** CLAUDE.md says "use Playwright for Tier 3" but there's no `tests/playwright/` directory, no `playwright.config`, no `fw test ui` command, no CI step. It's guidance without teeth.

**For whom:** Framework operators who want automated regression testing instead of manual Human AC pile-up.
**Why now:** T-954 established the classification reform. T-959/T-964/T-965/T-966 just built 4 Watchtower features that ALL should have had Playwright regression tests instead of Human ACs. The pattern will repeat on every UI task unless we build the infrastructure now.

## Assumptions

- A-001: Playwright MCP server (already installed) can be scripted into repeatable test files, not just ad-hoc session usage
- A-002: Flask test client + Playwright cover Tier 1 + Tier 3; TermLink dispatch covers Tier 2 — no additional tools needed
- A-003: Existing bats test runner pattern can extend to include Playwright and TermLink E2E
- A-004: A `fw test` command can orchestrate all 3 tiers with clear output
- A-005: CI (GitHub Actions) can run Playwright tests headlessly
- A-006: Converting existing Human ACs to automated tests is feasible for 30%+ of the backlog (the RUBBER-STAMP / deterministic ones)

## Exploration Plan

5 research vectors:

1. **Audit current test gap** (20min) — Categorize the 110+ unchecked Human ACs: how many are functional (automatable) vs genuinely subjective? What's the conversion potential?

2. **Playwright test infrastructure** (30min) — What does a `tests/playwright/` directory need? Config file, test runner, CI integration. Can we use Playwright MCP as the runner or do we need `npx playwright test`? How do existing Flask/Python projects run Playwright?

3. **TermLink E2E test pattern** (20min) — Design a repeatable pattern: spawn session, inject commands, assert output, cleanup. Can this reuse the existing `tests/e2e/` bash framework? What does a TermLink test file look like?

4. **fw test command design** (20min) — Unified test runner: `fw test` (all), `fw test unit` (bats), `fw test e2e` (TermLink), `fw test ui` (Playwright). Report format. CI integration.

5. **AC-to-test conversion pipeline** (20min) — When an Agent AC says "page returns 200 and contains X," can we auto-generate a test stub? Template pattern for Playwright tests from AC descriptions.

## Technical Constraints

- Playwright MCP is already installed as a Claude Code plugin
- Node.js available (Claude Code requirement, confirmed in T-586)
- GitHub Actions CI exists (T-476) — runs bats tests
- Watchtower must be running for Playwright tests (test setup/teardown)
- Tests must work on Linux (primary) and macOS (secondary)
- No heavy test framework — keep it simple (Playwright CLI, bats, bash)

## Scope Fence

**IN scope:**
- Research all 5 vectors
- Design test directory structure
- Design `fw test` command interface
- Propose AC-to-test conversion for existing backlog
- Go/no-go on building the infrastructure

**OUT of scope:**
- Actually writing all the Playwright tests (that's build tasks after GO)
- Rewriting existing bats tests
- Test coverage metrics or code coverage tools
- Performance/load testing

## Acceptance Criteria

### Agent
- [x] Problem statement validated with data (112 unchecked Human ACs: 19% automatable)
- [x] 5 research vectors completed (1 direct + 4 TermLink dispatch)
- [x] Research artifact created at `docs/reports/T-968-test-infrastructure.md`
- [x] Test directory structure proposed (tests/playwright/ with pytest-playwright)
- [x] `fw test` command already exists — extend with `fw test playwright`
- [x] Recommendation: GO — gap is focused (just Playwright integration needed)

### Human
- [x] [REVIEW] Review test infrastructure design and approve direction
  **Steps:**
  1. Read `docs/reports/T-968-test-infrastructure.md`
  2. Evaluate: does the 3-tier runner design fit the framework philosophy (bash orchestration, minimal deps)?
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-968 go|no-go --rationale "your rationale"`
  **Expected:** Decision on test infrastructure direction
  **If not:** Discuss concerns about complexity or approach

## Go/No-Go Criteria

**GO if:**
- 30%+ of unchecked Human ACs are convertible to automated tests
- Playwright tests can run without heavy infrastructure (no Docker, no separate test server)
- `fw test` command design is clean and fits existing CLI patterns
- CI integration is straightforward (extend existing GitHub Actions)

**NO-GO if:**
- Most Human ACs are genuinely subjective (low conversion potential)
- Playwright requires infrastructure that doesn't justify the maintenance
- Test setup/teardown is fragile (Watchtower must be running, ports must be free)
- The complexity of 3-tier testing exceeds the value of automated AC verification

## Verification

test -f docs/reports/T-968-test-infrastructure.md
grep -q '## Recommendation' docs/reports/T-968-test-infrastructure.md

## Recommendation

**Recommendation:** GO
**Rationale:** Gap is focused: add tests/playwright/ + fw test playwright. 1086 tests and fw test already exist. pytest-playwright is pure Python (no JS tooling). 19% of Human AC backlog is automatable, but the real value is going-forward regression prevention.
**Evidence:**
- fw test already has 5 sub-commands with 1086 tests
- pytest-playwright fits Flask/Python stack perfectly
- 12 AC-to-test conversion patterns identified
- Implementation is 1 session (3 focused build tasks)

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO
Rationale: Gap is focused: add tests/playwright/ + fw test playwright. 1086 tests and fw test already exist. pytest-playwright is pure Python (no JS tooling). 19% of Human AC backlog is automatable, but the real value is going-forward regression prevention.
Evidence:
- fw test already has 5 sub-commands with 1086 tests
- pytest-playwright fits Flask/Python stack perfectly
- 12 AC-to-test conversion patterns identified
- Implementation is 1 session (3 focused build tasks)

**Date**: 2026-04-06T19:37:23Z

## Updates

### 2026-04-06T19:21:20Z — task-created [task-create-agent]
- **Action:** Created inception task for test infrastructure codification
- **Context:** User feedback on T-959/T-964/T-965/T-966 — functional Human ACs should be automated tests

### 2026-04-06T19:37:23Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO
Rationale: Gap is focused: add tests/playwright/ + fw test playwright. 1086 tests and fw test already exist. pytest-playwright is pure Python (no JS tooling). 19% of Human AC backlog is automatable, but the real value is going-forward regression prevention.
Evidence:
- fw test already has 5 sub-commands with 1086 tests
- pytest-playwright fits Flask/Python stack perfectly
- 12 AC-to-test conversion patterns identified
- Implementation is 1 session (3 focused build tasks)

### 2026-04-06T19:37:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:24Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-78609671
- **Timestamp:** 2026-06-02T15:05:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
