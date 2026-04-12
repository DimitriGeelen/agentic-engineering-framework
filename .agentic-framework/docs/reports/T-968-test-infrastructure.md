# T-968: 3-Tier Test Infrastructure — Research Report

## Overview

Research into codifying the 3-tier test approach (programmatic, TermLink E2E, Playwright)
with infrastructure, `fw test` command, and AC-to-test conversion pipeline.

## Research Vectors

| # | Report | Size | Key Finding |
|---|--------|------|-------------|
| 1 | Direct analysis | — | 112 unchecked Human ACs: 19% automatable, 79% genuinely subjective |
| 2 | [Playwright Infrastructure](T-968-v2-playwright-infra.md) | 12KB | pytest-playwright (Python) — no JS tooling needed, 5 initial test files |
| 3 | [TermLink E2E Pattern](T-968-v3-termlink-e2e.md) | 16KB | Existing tests/e2e/ is TermLink-ready, need multi-step workflow tests |
| 4 | [fw test Command](T-968-v4-fw-test-command.md) | 16KB | **fw test already exists** (1086 tests) — just add `fw test playwright` sub-command |
| 5 | [AC-to-Test Pipeline](T-968-v5-ac-to-test-pipeline.md) | 22KB | 12 conversion patterns, 4 test templates, 6 workflow proposals |

## Synthesis

### Key Discovery: More Infrastructure Exists Than Expected

- `fw test` already has 5 sub-commands (unit, integration, web, lint, all) with 1086+ tests
- `tests/e2e/` has TermLink-ready bash E2E framework with runner, setup/teardown, assertions
- What's MISSING is specifically: `tests/playwright/` directory + `fw test playwright` sub-command

### The Real Gap is Smaller Than Assumed

The problem isn't "no test infrastructure." The problem is:
1. **No Playwright tests** — UI features get Human ACs instead of Playwright regression tests
2. **No AC-to-test conversion habit** — When writing ACs, nobody generates test stubs
3. **Backlog conversion is low-value** — 79% of unchecked Human ACs are genuinely subjective

### Proposed Architecture

```
tests/
  unit/          ← 688 bats tests (Tier 1) — EXISTS
  integration/   ← 368 bats tests (Tier 1) — EXISTS
  e2e/           ← TermLink E2E tests (Tier 2) — EXISTS (framework ready, few tests)
  playwright/    ← Browser UI tests (Tier 3) — NEW
    conftest.py       # pytest fixtures (server start, browser)
    test_smoke.py     # All routes return 200, render content
    test_terminal.py  # Terminal page, multi-session, TermLink attach
    test_inception.py # Batch review, recommendations inline
```

### fw test Integration

Extend existing `fw test` with one new sub-command:
```bash
fw test playwright   # Run Playwright tests (requires Watchtower running)
fw test all          # Now includes: unit + integration + web + playwright
```

### Going-Forward Workflow

When writing UI Agent ACs:
1. Write the AC: "Terminal page loads with xterm.js and tab bar"
2. Write the verification command: `grep -q 'xterm' web/templates/terminal.html`
3. **Also write the test file:** `tests/playwright/test_terminal.py`
4. The test becomes a permanent regression guard

## Recommendation

**Recommendation:** GO

**Rationale:** The gap is smaller and more focused than expected. We need exactly one new thing: `tests/playwright/` with pytest-playwright tests and `fw test playwright` sub-command. The rest of the infrastructure already exists. Implementation is 1 session.

**Evidence:**
- V1: Only 19% of Human AC backlog is automatable (low backlog conversion value, high going-forward value)
- V2: pytest-playwright is pure Python, no JS tooling, fits Flask stack perfectly
- V3: TermLink E2E framework already exists in tests/e2e/ — ready for more tests
- V4: `fw test` already has 5 sub-commands and 1086 tests — just extend with `playwright`
- V5: 12 conversion patterns identified, 4 test templates designed

**What to build (3 tasks):**
1. `tests/playwright/` directory + conftest.py + `fw test playwright` sub-command
2. 5 initial Playwright test files (smoke, terminal, inception, tasks, fabric)
3. GitHub Actions CI integration for Playwright (headless)

**Risk:** Low. Adding pytest-playwright to an existing Python test setup is well-understood. The tests are additive — no existing tests change.
