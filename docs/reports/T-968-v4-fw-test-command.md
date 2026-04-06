# T-968 Vector 4: `fw test` Command Design

## Status: COMPLETE

## Current State

The framework already has `fw test` with five sub-commands inline in `bin/fw:3669-3783`:

| Sub-command | Runner | What it runs | Test count |
|-------------|--------|-------------|------------|
| `fw test unit` | bats | `tests/unit/*.bats` | 688 tests (58 files) |
| `fw test integration` | bats | `tests/integration/*.bats` | 368 tests (69 files) |
| `fw test web` | pytest | `web/test_app.py` | ~30 tests (1099 lines) |
| `fw test lint` | shellcheck | All `.sh` files | N/A (linter) |
| `fw test all` | sequential | unit + integration + web | ~1086 total |

Separately, `tests/e2e/runner.sh` runs TermLink E2E tests:

| Runner | What it runs | Test count |
|--------|-------------|------------|
| `runner.sh --tier a` | `tests/e2e/tier-a/test-*.sh` | 7 scripts (shell-level, $0 cost) |
| `runner.sh --tier b` | `tests/e2e/tier-b/test-*.sh` | 2 scripts (agent-level, API cost) |

No Playwright tests exist yet (`tests/playwright/` does not exist).

GitHub Actions CI (`.github/workflows/test.yml`) runs:
- Job `bats`: `bats tests/integration/ tests/unit/`
- Job `e2e`: `bash tests/e2e/runner.sh --tier a`

## Gap Analysis

| Gap | Impact | Severity |
|-----|--------|----------|
| E2E not reachable via `fw test` | Two entry points, CI uses runner.sh directly | Medium |
| No `fw test e2e` sub-command | Agent/human must remember separate runner | Medium |
| No `--tier` flag on `fw test` | Can't select tier 1/2/3 from unified CLI | Low |
| No Playwright tier | UI tests have no infrastructure yet | Low (future) |
| No parallel execution | All tiers run sequentially in `all` mode | Low |
| No JSON/structured output from `fw test` | CI must parse text output | Low |
| No timing report | No per-suite elapsed time | Low |
| `fw doctor` doesn't check test health | No staleness or last-run tracking | Low |

## Proposed Design

### Command Interface

```
fw test [SUITE] [OPTIONS]

SUITES:
  all             Run all suites (default)
  unit            Bats unit tests
  integration     Bats integration tests
  web             Pytest web/Watchtower tests
  e2e             TermLink E2E tests (Tier A by default)
  ui              Playwright UI tests (future)
  lint            ShellCheck linting

OPTIONS:
  --tier a|b|all  E2E tier selection (only with 'e2e' suite)
  --json          Machine-readable JSON output
  --parallel      Run independent suites in parallel (unit+integration+web)
  --quick         Run only unit tests (alias for 'unit')
  --ci            Implies --json, sets CI-appropriate defaults
  -h, --help      Show help
```

### Tier Mapping

The 3-tier model from the inception maps onto suites:

| Tier | Verification type | `fw test` suite | Runner | Cost |
|------|-------------------|-----------------|--------|------|
| 1 | Programmatic | `unit`, `integration`, `web`, `lint` | bats, pytest, shellcheck | $0 |
| 2 | TermLink E2E | `e2e` | `tests/e2e/runner.sh` | $0 (Tier A) or API (Tier B) |
| 3 | Playwright | `ui` | `npx playwright test` | $0 |

The `--tier` flag is E2E-specific (passes through to `runner.sh --tier`). For selecting by verification tier across all suites, the suite names themselves are the selectors.

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |
| 2 | Usage error or missing dependency |

### Report Format (text mode)

```
=== Framework Test Suite ===

--- Bats Unit Tests (688 tests) ---
688 tests, 688 passed, 0 failed
  elapsed: 12.3s

--- Bats Integration Tests (368 tests) ---
368 tests, 365 passed, 3 failed
  elapsed: 8.7s

--- Web Tests (pytest) ---
30 passed, 0 failed
  elapsed: 4.1s

--- E2E Tier A (7 scenarios) ---
7 pass, 0 fail, 0 skip
  elapsed: 45.2s

=== Summary ===
  Unit:        688/688 PASS      12.3s
  Integration: 365/368 FAIL       8.7s
  Web:          30/30  PASS       4.1s
  E2E:           7/7   PASS      45.2s
  Lint:        142/142 PASS       3.8s
  ─────────────────────────────────────
  Total:      1090/1095           74.1s
  Result:     FAIL (3 failures)
```

### Report Format (JSON mode)

```json
{
  "timestamp": "2026-04-06T15:30:00Z",
  "fw_version": "1.4.12",
  "suites": {
    "unit":        { "total": 688, "pass": 688, "fail": 0, "skip": 0, "elapsed_s": 12.3, "status": "pass" },
    "integration": { "total": 368, "pass": 365, "fail": 3, "skip": 0, "elapsed_s": 8.7, "status": "fail" },
    "web":         { "total": 30,  "pass": 30,  "fail": 0, "skip": 0, "elapsed_s": 4.1, "status": "pass" },
    "e2e":         { "total": 7,   "pass": 7,   "fail": 0, "skip": 0, "elapsed_s": 45.2, "status": "pass" },
    "lint":        { "total": 142, "pass": 142, "fail": 0, "skip": 0, "elapsed_s": 3.8, "status": "pass" }
  },
  "summary": { "total": 1095, "pass": 1090, "fail": 3, "skip": 0, "elapsed_s": 74.1, "status": "fail" }
}
```

### Dependency Checks

Before running each suite, check prerequisites and skip with `SKIP` (not error) if missing:

| Suite | Dependency | Check command |
|-------|-----------|---------------|
| unit, integration | bats | `command -v bats` |
| web | pytest | `python3 -c "import pytest"` |
| e2e | termlink | `command -v termlink` |
| ui | playwright | `npx playwright --version` |
| lint | shellcheck | `command -v shellcheck` |

Missing dependency = SKIP with warning, not FAIL. This keeps `fw test all` useful on machines without all tools installed.

### Integration with `fw doctor`

`fw doctor` should NOT run tests (too slow, wrong context). Instead, add a check:

```
  OK   Test infrastructure (688 unit, 368 integration, 7 e2e)
  WARN Test staleness: last run 3 days ago (tests/last-run.json)
```

Implementation: `fw test` writes `.context/working/.test-last-run.json` after each run. `fw doctor` reads it and reports staleness (>7 days = WARN).

### Parallelism

Tier 1 suites (unit, integration, web, lint) are independent and CAN run in parallel. E2E tests may conflict with each other (shared TermLink sessions, port binds).

Strategy:
- `--parallel` flag runs Tier 1 suites via background processes + `wait`
- E2E always runs sequentially after Tier 1 completes
- Default: sequential (simpler output, easier debugging)
- CI: parallel (faster, output captured per-suite)

Implementation sketch:

```bash
if [ "$PARALLEL" = true ]; then
    _run_suite unit   > "$TMP/unit.log" 2>&1 &
    _run_suite integration > "$TMP/integration.log" 2>&1 &
    _run_suite web    > "$TMP/web.log" 2>&1 &
    _run_suite lint   > "$TMP/lint.log" 2>&1 &
    wait
    # Collect exit codes from $TMP/*.exit
    _run_suite e2e  # Sequential
fi
```

### CI Integration

Updated `.github/workflows/test.yml`:

```yaml
jobs:
  test:
    name: Framework Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.x'

      - name: Install dependencies
        run: |
          pip install pyyaml pytest
          # Install bats
          git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats
          sudo /tmp/bats/install.sh /usr/local

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'

      - name: Type check TypeScript
        run: |
          if [ -d lib/ts/src ] && find lib/ts/src -name '*.ts' -not -name '*.d.ts' | grep -q .; then
            cd lib/ts && npm ci && npx tsc --noEmit
          fi

      - name: Run tests (Tier 1)
        run: bin/fw test unit integration web lint --ci

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: .context/working/.test-last-run.json

  e2e:
    name: E2E Tests (Tier A)
    runs-on: ubuntu-latest
    needs: test  # Only run E2E if Tier 1 passes
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.x'

      - name: Install dependencies
        run: pip install pyyaml

      - name: Install TermLink
        run: |
          if ! command -v termlink >/dev/null 2>&1; then
            git clone --depth 1 https://github.com/DimitriGeelen/termlink.git /tmp/termlink
            cargo install --path /tmp/termlink/crates/termlink-cli
          fi

      - name: Run E2E tests
        run: bin/fw test e2e --tier a --ci
```

Key CI changes:
1. Single `fw test` entry point replaces direct `bats` and `runner.sh` calls
2. E2E runs as separate job that depends on Tier 1 passing
3. Test results artifact for CI dashboards
4. `--ci` flag implies `--json` output

### Implementation Plan

The existing `fw test` in `bin/fw:3669-3783` is already inline. The proposed changes:

1. **Extract to `lib/test.sh`** — Move the 114-line inline block to a proper lib file (follows `lib/costs.sh`, `lib/config.sh` pattern)

2. **Add `e2e` sub-command** — Delegates to `tests/e2e/runner.sh` with `--tier` passthrough

3. **Add `ui` sub-command** — Stub that checks for Playwright, runs `npx playwright test tests/playwright/` when tests exist, SKIPs otherwise

4. **Add `--json` flag** — Wraps each suite runner, captures exit codes, produces JSON summary

5. **Add `--parallel` flag** — Background + wait for Tier 1 suites

6. **Add timing** — `date +%s.%N` before/after each suite, reported in summary

7. **Add last-run tracking** — Write `.context/working/.test-last-run.json` after every run

8. **Update `do_doctor`** — Add test staleness check reading last-run file

### `lib/test.sh` Implementation Sketch

```bash
#!/bin/bash
# fw test — Unified test runner for the Agentic Engineering Framework

test_main() {
    local suites=()
    local json=false
    local parallel=false
    local e2e_tier="a"

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            unit|integration|web|e2e|ui|lint|all) suites+=("$1"); shift ;;
            --json|--ci) json=true; shift ;;
            --parallel)  parallel=true; shift ;;
            --tier)      e2e_tier="$2"; shift 2 ;;
            --quick)     suites=("unit"); shift ;;
            -h|--help)   _test_usage; return 0 ;;
            *)           echo "Unknown: $1" >&2; return 2 ;;
        esac
    done

    # Default: all
    [ ${#suites[@]} -eq 0 ] && suites=("all")

    # Expand 'all'
    if [[ " ${suites[*]} " == *" all "* ]]; then
        suites=(lint unit integration web e2e)
    fi

    local overall_exit=0
    local results=()
    local start_time
    start_time=$(date +%s)

    for suite in "${suites[@]}"; do
        local suite_start suite_end elapsed exit_code=0
        suite_start=$(date +%s)

        case "$suite" in
            unit)
                if ! command -v bats >/dev/null 2>&1; then
                    _skip "$suite" "bats not installed"; continue
                fi
                [ "$json" = false ] && echo -e "${BOLD}--- Bats Unit Tests ---${NC}"
                bats "$FRAMEWORK_ROOT/tests/unit/" || exit_code=$?
                ;;
            integration)
                if ! command -v bats >/dev/null 2>&1; then
                    _skip "$suite" "bats not installed"; continue
                fi
                [ "$json" = false ] && echo -e "${BOLD}--- Bats Integration Tests ---${NC}"
                bats "$FRAMEWORK_ROOT/tests/integration/" || exit_code=$?
                ;;
            web)
                if ! python3 -c "import pytest" 2>/dev/null; then
                    _skip "$suite" "pytest not installed"; continue
                fi
                [ "$json" = false ] && echo -e "${BOLD}--- Web Tests (pytest) ---${NC}"
                (cd "$FRAMEWORK_ROOT" && python3 -m pytest web/test_app.py -v) || exit_code=$?
                ;;
            e2e)
                if ! command -v termlink >/dev/null 2>&1; then
                    _skip "$suite" "termlink not installed"; continue
                fi
                [ "$json" = false ] && echo -e "${BOLD}--- E2E Tests (Tier ${e2e_tier^^}) ---${NC}"
                local runner_args=(--tier "$e2e_tier")
                [ "$json" = true ] && runner_args+=(--json)
                bash "$FRAMEWORK_ROOT/tests/e2e/runner.sh" "${runner_args[@]}" || exit_code=$?
                ;;
            ui)
                if ! npx playwright --version >/dev/null 2>&1; then
                    _skip "$suite" "playwright not installed"; continue
                fi
                if [ ! -d "$FRAMEWORK_ROOT/tests/playwright" ]; then
                    _skip "$suite" "no playwright tests"; continue
                fi
                [ "$json" = false ] && echo -e "${BOLD}--- Playwright UI Tests ---${NC}"
                npx playwright test "$FRAMEWORK_ROOT/tests/playwright/" || exit_code=$?
                ;;
            lint)
                if ! command -v shellcheck >/dev/null 2>&1; then
                    _skip "$suite" "shellcheck not installed"; continue
                fi
                [ "$json" = false ] && echo -e "${BOLD}--- ShellCheck Lint ---${NC}"
                _run_lint || exit_code=$?
                ;;
        esac

        suite_end=$(date +%s)
        elapsed=$((suite_end - suite_start))
        [ "$exit_code" -ne 0 ] && overall_exit=1

        results+=("$suite:$exit_code:${elapsed}s")
        [ "$json" = false ] && echo ""
    done

    # Summary
    _print_summary "${results[@]}"

    # Write last-run file
    _write_last_run "${results[@]}"

    return $overall_exit
}

_skip() {
    local suite="$1" reason="$2"
    echo -e "  ${YELLOW}SKIP${NC}  $suite ($reason)"
    results+=("$suite:skip:0s")
}

_write_last_run() {
    local file="$PROJECT_ROOT/.context/working/.test-last-run.json"
    mkdir -p "$(dirname "$file")"
    # Write JSON with timestamp and per-suite results
    python3 -c "
import json, datetime
results = []
for r in '''$*'''.split():
    parts = r.split(':')
    if len(parts) >= 3:
        results.append({'suite': parts[0], 'exit': parts[1], 'elapsed': parts[2]})
json.dump({
    'timestamp': datetime.datetime.utcnow().isoformat() + 'Z',
    'results': results
}, open('$file', 'w'), indent=2)
" 2>/dev/null || true
}
```

### Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Extract to `lib/test.sh`? | Yes | Inline block is already 114 lines, will grow to ~200. Matches `lib/costs.sh` pattern. |
| E2E via delegation? | Yes, delegate to `runner.sh` | Runner has its own arg parsing, JSON output, TermLink checks. Don't duplicate. |
| `--tier` scope? | E2E only | Tiers 1/2/3 map to suite groups, not a cross-cutting flag. Suite names are clearer. |
| Parallel default? | Off | Sequential output is easier to read. CI can opt-in with `--parallel`. |
| `fw doctor` runs tests? | No | Too slow. Doctor checks test staleness via last-run file instead. |
| Missing dep = FAIL or SKIP? | SKIP | `fw test all` on a minimal machine should still run what it can. |
| Playwright now? | Stub only | No tests exist yet. Wire the plumbing so adding tests is just creating the directory. |

### Migration

1. Move existing inline code from `bin/fw:3669-3783` to `lib/test.sh`
2. Replace inline block with: `source "$FW_LIB_DIR/test.sh"; test_main "$@"`
3. Add `e2e` and `ui` sub-commands
4. Update CI to use `fw test` instead of direct runners
5. No breaking changes — existing `fw test unit`, `fw test lint` etc. continue to work

### What This Unblocks

- **Vector 2 (Playwright):** `fw test ui` ready to accept tests once `tests/playwright/` is created
- **Vector 3 (TermLink E2E):** `fw test e2e` provides unified entry point
- **Vector 5 (AC-to-test pipeline):** Pipeline targets `fw test` sub-commands by tier
- **CI unification:** Single `fw test --ci` replaces scattered runner invocations
