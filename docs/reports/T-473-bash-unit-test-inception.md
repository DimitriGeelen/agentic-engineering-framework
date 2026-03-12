# T-473: Bash Unit Test Suite Inception — Research Report

**Date:** 2026-03-12
**Decision:** GO (Option B+ — pragmatic MVP with existing infrastructure)
**Effort estimate:** ~7 hours total

---

## Executive Summary

Marc's question "What are the unit tests for bash?" exposed a gap: the framework's enforcement layer (12 gate scripts in `agents/context/`) had only 25% test coverage. Five parallel research agents investigated: framework comparison, testability inventory, proof-of-concept, CI patterns, and ROI scoring.

**Key discovery:** 172 bats tests already exist (T-159/T-160). We're not starting from zero — we're extending. 16 tests are failing and need fixing, 9 gate scripts need coverage.

---

## Part 1: Current State (CI Agent)

### Existing Test Infrastructure
```
tests/
├── test_helper.bash          (shared setup, helpers)
├── fixtures/                 (empty)
├── unit/                     (5 files, 95 tests)
│   ├── context_focus.bats
│   ├── git_common.bats
│   ├── git_log.bats
│   ├── healing_diagnose.bats
│   └── healing_suggest.bats
└── integration/              (3 files, 77 tests)
    ├── check_active_task.bats
    ├── check_tier0.bats
    └── error_watchdog.bats
```

- **bats-core 1.13.0** already installed
- **172 total tests**, 16 failing (stale after recent refactoring)
- **`fw test`** command exists (runs `bats tests/`)
- **test_helper.bash** provides: `create_test_project()`, `create_test_task()`, auto temp-dir cleanup

### Coverage by Category
| Category | Tested | Total | Coverage |
|----------|--------|-------|----------|
| PreToolUse hooks | 2/5 | 5 | 40% |
| PostToolUse/background | 1/3 | 3 | 33% |
| Agents/utilities | 1/4 | 4 | 25% |
| **Overall** | **3/12** | **12** | **25%** |

---

## Part 2: Gate Scripts Inventory (Evaluate Agent)

**10 gate scripts, 1,663 lines of code total.**

### Scripts WITH tests (3)
1. **check-active-task.sh** (244 LoC, HIGH complexity) — 20 tests, 4 failing
2. **check-tier0.sh** (227 LoC, VERY HIGH) — 34 tests, comprehensive
3. **error-watchdog.sh** — 23 tests, comprehensive

### Scripts WITHOUT tests (9)
4. **block-plan-mode.sh** — TRIVIAL (single exit-code gate)
5. **check-dispatch.sh** — MEDIUM (preamble validation)
6. **check-fabric-new-file.sh** — MEDIUM (file registration advisory)
7. **budget-gate.sh** (253 LoC, VERY HIGH) — transcript parsing, cache logic
8. **checkpoint.sh** — HIGH (budget monitoring, auto-handover trigger)
9. **bus-handler.sh** — MEDIUM (YAML envelope processing)
10. **context.sh** — VERY HIGH (large agent entry point, many subcommands)
11. **pre-compact.sh** — MEDIUM (handover generation trigger)
12. **post-compact-resume.sh** — MEDIUM (context reinjection)

### Estimated Test Cases Needed
| Script | Est. Tests | Difficulty |
|--------|-----------|------------|
| check-active-task.sh (fix) | 4 failing | Easy |
| block-plan-mode.sh | 3 | Easy |
| check-dispatch.sh | 5 | Medium |
| check-fabric-new-file.sh | 5 | Medium |
| budget-gate.sh | 15 | Hard |
| checkpoint.sh | 8 | Medium |
| bus-handler.sh | 5 | Medium |
| pre-compact.sh | 5 | Medium |
| post-compact-resume.sh | 5 | Medium |
| **Total new** | **~55** | — |

---

## Part 3: Proof of Concept (POC Agent)

Wrote 5 bats tests for check-active-task.sh at `/tmp/fw-agent-t473-poc-test.bats`.

**Results: 5/5 PASS in 700ms.**

```
ok 1 allow: active task with real ACs exits 0          (195ms)
ok 2 block: no active task exits 2                     (134ms)
ok 3 block: placeholder ACs exits 2 (G-020)            (155ms)
ok 4 allow: exempt path .context/ exits 0              (70ms)
ok 5 block: captured status exits 2                    (139ms)
```

**Key findings:**
- Scripts testable WITHOUT modification (env var isolation via PROJECT_ROOT)
- `lib/paths.sh` guard (`_FW_PATHS_LOADED`) respects pre-set env vars
- stdin piping: `run bash -c 'echo JSON | bash script'` pattern works cleanly
- Per-test execution: ~100-200ms (dominated by Python subprocess for YAML parsing)

---

## Part 4: ROI Scoring (Score Agent)

### Evidence: 5 Gate Incidents in 7 Months
1. **T-062/T-063:** Task-first gate bypass (20 skills task-unaware) — 2 days
2. **T-092/T-094:** Tier 0 pattern false positives (heredoc) — iteration cycles
3. **T-148/T-149:** Budget gate FRAMEWORK_ROOT/PROJECT_ROOT confusion — 2+ days
4. **T-232:** Task gate missing file validation (3 days undetected)
5. **T-471:** G-020 scope bypass (placeholder ACs) — 2 hours human intervention

**Total human cost:** ~8-10 days incident response

### Decision Matrix
| Option | Score | Effort | Notes |
|--------|-------|--------|-------|
| A: Do Nothing | 47/75 | 0h | Reactive; incidents repeat |
| B: bats MVP (no CI) | 47/75 | 20h | False positives without CI |
| **B+: Pragmatic MVP** | **~58/75** | **~7h** | **Extend existing 172 tests** |
| C: Comprehensive | 61/75 | 70-90h | Full coverage + CI matrix |
| D: DIY Bash | 41/75 | 50h | Invents wheel |
| E: Python pytest | 57/75 | 35h | Dual stack concern |

### Why Option B+ (not B or C)
- **B assumes starting from zero** (20h) — but 172 tests already exist, so ~7h
- **C is overkill** now — 12 scripts × 20 tests × 20 min = 70-90h; gate changes are rare post-stabilization
- **B+ extends existing infrastructure**: fix 16 failing, add ~55 new tests for 9 uncovered gates

---

## Part 5: Implementation Plan

### Phase 1: Fix Failing Tests (~1.5h)
- Fix 4 failing check_active_task.bats tests (recent G-020 refactoring)
- Fix 12 other failures across unit tests
- Verify `fw test` passes clean

### Phase 2: Cover Missing Gates (~4.25h)
Priority order (by risk × effort):
1. **budget-gate.sh** — 15 tests, ~1.5h (highest risk, hardest)
2. **block-plan-mode.sh** — 3 tests, ~15min (trivial)
3. **check-dispatch.sh** — 5 tests, ~30min
4. **check-fabric-new-file.sh** — 5 tests, ~30min
5. **checkpoint.sh** — 8 tests, ~45min
6. **bus-handler.sh** — 5 tests, ~30min
7. **pre-compact.sh + post-compact-resume.sh** — 10 tests, ~45min

### Phase 3: CI + Documentation (~1.25h)
- GitHub Actions workflow for bats
- Update `fw test` to include new test files
- Document test patterns in test_helper.bash comments

### Total: ~7 hours

---

## Assumptions Validated

| # | Assumption | Status | Evidence |
|---|-----------|--------|----------|
| A-1 | bats-core is right framework | VALIDATED | Already installed, 172 tests, ecosystem mature |
| A-2 | Scripts testable in isolation | VALIDATED | POC: 5/5 pass, env var isolation works |
| A-3 | Tests run <30s total | VALIDATED | 172 tests in ~10s |
| A-4 | Test fixtures manageable | VALIDATED | test_helper.bash helpers exist |

---

*Consolidated from 5 parallel research agents. Original reports: /tmp/fw-agent-t473-{research,evaluate,poc,ci,score}.md*
