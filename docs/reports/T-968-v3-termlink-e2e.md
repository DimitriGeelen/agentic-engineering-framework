# T-968 Vector 3: TermLink E2E Test Pattern Design

## Status: COMPLETE

## Executive Summary

The existing `tests/e2e/` infrastructure is already TermLink-ready. The libraries (`setup.sh`, `teardown.sh`, `assert.sh`) provide session management, isolation, and TermLink-specific assertions. What's missing is a **repeatable pattern for testing fw CLI workflows** — not primitives (TL1-TL4 cover those) but multi-step command sequences that exercise the framework as users experience it.

This report designs that pattern, provides a sample test, and identifies 10 candidate workflows.

## Findings

### 1. Existing Infrastructure Assessment

The E2E framework already has everything needed:

| Component | Location | TermLink Support |
|-----------|----------|------------------|
| Runner | `tests/e2e/runner.sh` | Tier A/B discovery, JSON output, TermLink dependency check |
| Setup | `tests/e2e/lib/setup.sh` | `setup_isolated_env()`, `setup_termlink_session()`, `tl_run/tl_run_exit/tl_run_output` helpers |
| Teardown | `tests/e2e/lib/teardown.sh` | EXIT trap: session exit + `termlink clean` + rm temp dir |
| Assertions | `tests/e2e/lib/assert.sh` | `assert_tl_exit()`, `assert_tl_output_contains()` |
| Primitives | `tests/e2e/tier-a/test-termlink-primitives.sh` | Spawn, interact, cleanup, fw commands |
| Lifecycle | `tests/e2e/tier-b/test-lifecycle.sh` | Full Claude-in-TermLink pattern |

**Conclusion:** No new runner or library needed. TermLink E2E tests go in `tests/e2e/tier-a/` (no API cost) and follow the existing conventions.

### 2. The TermLink E2E Test Pattern

A TermLink E2E test differs from a "shell-level" test (like `test-task-gate.sh`) in one key way: **it runs commands through TermLink instead of piping JSON to hook scripts directly**. This tests the full command path — PATH resolution, environment, shell state, inter-command side effects.

#### Pattern: Setup → Execute → Assert → Teardown

```
Phase 1: SETUP
  - setup_isolated_env        → temp dir with minimal framework + git init
  - setup_termlink_session    → spawn background shell session, cd to TEST_DIR
  - Seed test state           → create task files, focus, config as needed

Phase 2: EXECUTE
  - tl_run_exit "fw command"  → run command via TermLink, get exit code
  - tl_run_output "fw command" → run command, get stdout
  - tl_run "fw command"       → run command, get full JSON (exit_code + output)

Phase 3: ASSERT
  - assert_tl_exit SESSION CMD EXPECTED SCENARIO DESC
  - assert_tl_output_contains SESSION CMD PATTERN SCENARIO DESC
  - Manual: parse tl_run JSON for complex assertions (YAML field values, file contents)

Phase 4: TEARDOWN
  - Automatic via EXIT trap (teardown.sh)
  - Session exit + termlink clean + rm TEST_DIR
```

#### Why TermLink Instead of Direct Execution?

| Direct (`bash -c "fw task create"`) | Via TermLink (`tl_run "fw task create"`) |
|------|------|
| Tests the script in isolation | Tests the full PATH + env + shell state |
| Can't detect env pollution between commands | Sequential commands share shell state (realistic) |
| Can't test interactive sequences | Can inject keystrokes, wait for output |
| Fast (no process spawn overhead) | ~100ms per interact call (acceptable) |

**Rule of thumb:** Use direct execution for unit-testing a single hook/script. Use TermLink for testing multi-step workflows where command order and state carry-over matter.

### 3. Test Isolation Model

Isolation is already solved by `setup.sh`:

1. **Filesystem:** `mktemp -d` creates `/tmp/fw-e2e-XXXXXX/` per test. Framework subset copied in (`bin/`, `lib/`, `agents/`). Git repo initialized.
2. **Session:** `fw-e2e-$$` naming ensures unique TermLink sessions per test process.
3. **State:** Each test starts with clean `.tasks/`, `.context/` directories. Tests that need pre-existing state seed it explicitly.
4. **Cleanup:** EXIT trap removes everything. `termlink clean` handles orphaned sessions.

**One gap to address:** If a test spawns a session and then the test script is killed (`SIGKILL`), the EXIT trap doesn't fire and the session leaks. Mitigation: `termlink clean` before `runner.sh` starts (already implied by the primitives test cleanup pattern). Add to runner.sh:

```bash
# Pre-run cleanup: remove any leaked e2e sessions
termlink list --json 2>/dev/null | python3 -c "
import sys,json
for s in json.load(sys.stdin):
    if 'e2e' in s.get('tags',''):
        print(s['name'])
" 2>/dev/null | while read -r name; do
    termlink signal "$name" SIGTERM 2>/dev/null || true
done
termlink clean 2>/dev/null || true
```

### 4. Handling Timeouts and Flaky Tests

**Timeouts:**
- `tl_run` defaults to 30s timeout (configurable second arg)
- `setup_termlink_session` uses 15s `--wait-timeout` for spawn
- For slow commands (context init, handover generation): pass explicit timeout `tl_run "fw handover" 60`
- Timeout produces empty/error JSON — assertions fail with clear message, not hang

**Flaky test mitigation:**
1. **Deterministic state:** Tests seed exactly the state they need (task files, focus.yaml, config). Never depend on prior test's side effects.
2. **Idempotent assertions:** Check for presence/absence, not exact counts (git log may have extra commits from hooks).
3. **Retry for timing:** If a command needs filesystem to settle, add `tl_run "sync" 5` before asserting (rare — only for commands that fork background processes).
4. **Skip gracefully:** If `termlink` is not installed, skip with `skip()` function (exit 0, not failure).

### 5. Sample Test File

```bash
#!/usr/bin/env bash
# Tier A Tests: Task Lifecycle via TermLink (A-WF-TASK)
# Tests fw work-on → edit → commit → complete cycle through TermLink.
#
# WF1: fw work-on creates task and sets focus
# WF2: fw git commit with task reference succeeds
# WF3: fw task update to work-completed moves task to completed/
# WF4: fw context focus shows current task

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/setup.sh"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/teardown.sh"

SUITE_NAME="tier-a-workflow-task-lifecycle"

# ── Preflight ──

if ! command -v termlink >/dev/null 2>&1; then
    skip "WF1" "fw work-on creates task" "termlink not installed"
    skip "WF2" "fw git commit succeeds" "termlink not installed"
    skip "WF3" "fw task update completes" "termlink not installed"
    skip "WF4" "fw context focus shows task" "termlink not installed"
    if [ "${JSON_OUTPUT:-false}" = true ]; then print_json_summary; else print_summary; fi
    exit 0
fi

# ── Setup ──

setup_isolated_env
setup_termlink_session "fw-e2e-wf-$$"

# Initialize framework context inside the session
tl_run "bin/fw context init 2>/dev/null" 10 >/dev/null

# ── WF1: fw work-on creates task and sets focus ──

RESULT=$(tl_run "bin/fw work-on 'E2E lifecycle test' --type build --owner agent 2>&1" 15)
WF1_EXIT=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exit_code',-1))" 2>/dev/null) || WF1_EXIT=-1
WF1_OUTPUT=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('output',''))" 2>/dev/null) || WF1_OUTPUT=""

# Extract task ID from output (e.g., "T-001")
TASK_ID=$(echo "$WF1_OUTPUT" | grep -oE 'T-[0-9]+' | head -1) || TASK_ID=""

if [ "$WF1_EXIT" = "0" ] && [ -n "$TASK_ID" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "WF1" "fw work-on creates task ($TASK_ID)" "PASS"
    printf "${_G}PASS${_N} [WF1] fw work-on creates task (%s)\n" "$TASK_ID"
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _record_result "WF1" "fw work-on creates task" "FAIL" "exit=$WF1_EXIT task_id='$TASK_ID'"
    printf "${_R}FAIL${_N} [WF1] fw work-on creates task (exit=%s id='%s')\n" "$WF1_EXIT" "$TASK_ID"
fi

# ── WF4: fw context focus shows current task ──

assert_tl_output_contains "$TEST_SESSION" \
    "bin/fw context focus 2>&1" \
    "$TASK_ID" \
    "WF4" "fw context focus shows current task"

# ── WF2: Create a file and commit via fw git ──

tl_run "echo 'test content' > test-file.txt" 5 >/dev/null
tl_run "git add test-file.txt" 5 >/dev/null

assert_tl_exit "$TEST_SESSION" \
    "bin/fw git commit -m '$TASK_ID: Add test file' 2>&1" \
    0 "WF2" "fw git commit with task reference succeeds"

# ── WF3: Complete the task ──

# Check all Agent ACs first (simulating agent behavior)
if [ -n "$TASK_ID" ]; then
    # Find the task file and check the AC
    TASK_SLUG=$(tl_run_output "ls .tasks/active/ | grep '$TASK_ID' | head -1" 5)
    if [ -n "$TASK_SLUG" ]; then
        tl_run "sed -i 's/- \\[ \\]/- [x]/' '.tasks/active/$TASK_SLUG'" 5 >/dev/null
        tl_run "git add '.tasks/active/$TASK_SLUG' && git commit -m '$TASK_ID: Check ACs' --no-verify" 5 >/dev/null
    fi
fi

RESULT=$(tl_run "bin/fw task update $TASK_ID --status work-completed 2>&1" 30)
WF3_EXIT=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exit_code',-1))" 2>/dev/null) || WF3_EXIT=-1

# Task should have moved to completed/
COMPLETED_COUNT=$(tl_run_output "ls .tasks/completed/ 2>/dev/null | grep -c '$TASK_ID'" 5) || COMPLETED_COUNT="0"

if [ "${COMPLETED_COUNT:-0}" -gt 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    _record_result "WF3" "Task moved to completed/" "PASS"
    printf "${_G}PASS${_N} [WF3] Task moved to completed/\n"
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _record_result "WF3" "Task moved to completed/" "FAIL" "exit=$WF3_EXIT completed_count=$COMPLETED_COUNT"
    printf "${_R}FAIL${_N} [WF3] Task moved to completed/ (exit=%s count=%s)\n" "$WF3_EXIT" "$COMPLETED_COUNT"
fi

# ── Report ──

if [ "${JSON_OUTPUT:-false}" = true ]; then
    print_json_summary
else
    print_summary
fi
```

### 6. Candidate Workflows for TermLink E2E Testing

These are multi-step CLI workflows where TermLink adds value over direct hook testing. Ordered by priority (coverage gap x frequency of use):

| # | Workflow | Scenarios | Why TermLink |
|---|----------|-----------|--------------|
| 1 | **Task lifecycle** (`fw work-on` → edit → commit → complete) | WF1-WF4 (sample above) | Tests full state carry-over: task creation, focus, commit hook, completion gate, file move |
| 2 | **Verification gate** (`fw task update --status work-completed` with passing/failing `## Verification` commands) | VG1: pass, VG2: fail blocks, VG3: `--force` bypasses | Verification runs shell commands inside the task context — TermLink tests the real execution |
| 3 | **Healing loop** (`fw task update --status issues` → `fw healing diagnose` → `fw healing resolve`) | HL1: auto-diagnosis on status change, HL2: pattern lookup, HL3: resolution recorded | Multi-command sequence with state changes between steps |
| 4 | **Context fabric** (`fw context init` → `fw context focus` → `fw context add-learning` → `fw context status`) | CF1: init creates files, CF2: focus persists, CF3: learning recorded, CF4: status accurate | Tests YAML state accumulation across commands |
| 5 | **Git traceability** (`fw git commit` with/without task ref, `fw git status`, `fw git log --traceability`) | GT1: commit-msg hook rejects no task ref, GT2: passes with ref, GT3: traceability report | Hook enforcement requires real git environment + shell state |
| 6 | **Handover generation** (`fw handover` → verify output → `fw handover --commit`) | HO1: generates LATEST.md, HO2: --commit creates git commit, HO3: content non-empty | Tests file generation + git integration in sequence |
| 7 | **Audit compliance** (`fw audit` after various states: clean, missing task, stale task) | AU1: clean pass, AU2: stale task warning, AU3: missing focus warning | Audit reads multiple framework state files — tests real filesystem state |
| 8 | **Inception workflow** (`fw inception start` → explore → `fw inception decide go`) | IN1: creates inception task, IN2: commit limit enforcement, IN3: go decision recorded | Multi-phase workflow with commit-hook gate changes |
| 9 | **Bus result ledger** (`fw bus post` → `fw bus manifest` → `fw bus read` → `fw bus clear`) | BU1: post creates envelope, BU2: manifest lists, BU3: read returns content, BU4: clear removes | YAML envelope lifecycle — tests serialization/deserialization |
| 10 | **Config resolution** (`fw config set` → `fw config get` → env var override → `fw config overrides`) | CO1: set writes .framework.yaml, CO2: get reads, CO3: env var wins, CO4: overrides lists | Tests 4-tier resolution (flag > env > file > default) with real shell env |

### 7. Test File Naming Convention

Following existing patterns (`test-termlink-primitives.sh`, `test-task-gate.sh`, `test-tier0.sh`):

```
tests/e2e/tier-a/test-wf-task-lifecycle.sh     # Workflow: task lifecycle (WF1-WF4)
tests/e2e/tier-a/test-wf-verification-gate.sh  # Workflow: verification gate (VG1-VG3)
tests/e2e/tier-a/test-wf-healing-loop.sh       # Workflow: healing loop (HL1-HL3)
tests/e2e/tier-a/test-wf-context-fabric.sh     # Workflow: context fabric (CF1-CF4)
tests/e2e/tier-a/test-wf-git-traceability.sh   # Workflow: git traceability (GT1-GT3)
tests/e2e/tier-a/test-wf-handover.sh           # Workflow: handover generation (HO1-HO3)
tests/e2e/tier-a/test-wf-audit.sh              # Workflow: audit compliance (AU1-AU3)
tests/e2e/tier-a/test-wf-inception.sh          # Workflow: inception workflow (IN1-IN3)
tests/e2e/tier-a/test-wf-bus.sh                # Workflow: bus result ledger (BU1-BU4)
tests/e2e/tier-a/test-wf-config.sh             # Workflow: config resolution (CO1-CO4)
```

Prefix `wf-` distinguishes workflow E2E tests from existing gate/hook tests. All Tier A (no API cost). The runner auto-discovers them.

### 8. Scenario ID Convention

Extend the existing scheme:

| Prefix | Meaning | Example |
|--------|---------|---------|
| `A1-A9` | Gate/hook tests (existing) | `A1: Task gate blocks` |
| `TL1-TL9` | TermLink primitives (existing) | `TL2: Interact returns JSON` |
| `WF1-WF9` | Workflow: task lifecycle | `WF1: fw work-on creates task` |
| `VG1-VG9` | Workflow: verification gate | `VG2: Failing verification blocks completion` |
| `HL1-HL9` | Workflow: healing loop | `HL1: Status issues triggers diagnosis` |
| `B1` | Tier B agent lifecycle (existing) | `B1a: Agent created a task` |

### 9. Estimated Test Counts

| Category | Tests | TermLink Sessions | Estimated Runtime |
|----------|-------|-------------------|-------------------|
| Task lifecycle | 4 | 1 | ~15s |
| Verification gate | 3 | 1 | ~10s |
| Healing loop | 3 | 1 | ~10s |
| Context fabric | 4 | 1 | ~12s |
| Git traceability | 3 | 1 | ~10s |
| Handover | 3 | 1 | ~15s |
| Audit | 3 | 1 | ~10s |
| Inception | 3 | 1 | ~12s |
| Bus ledger | 4 | 1 | ~10s |
| Config resolution | 4 | 1 | ~10s |
| **Total** | **34** | **10** | **~2 min** |

Each test file spawns one session and runs all its scenarios sequentially within it (shared state is the point — we're testing workflows). Total wall time ~2 minutes for all 10 workflow test files.

### 10. Runner Integration

No changes needed to `runner.sh`. The `wf-*` files are auto-discovered by:

```bash
discover_tests() {
    local dir="$RUNNER_DIR/tier-$tier"
    find "$dir" -name 'test-*.sh' -type f | sort
}
```

To run just workflow tests: `./runner.sh --scenario wf-task-lifecycle`
To run all Tier A (including workflow): `./runner.sh --tier a`

**One improvement:** Add a pre-run cleanup step to `runner.sh` to kill leaked e2e sessions (see section 3). This prevents session name collisions if a previous run was killed.

## Recommendation

**GO — Build the 10 workflow test files.**

Rationale:
- Infrastructure exists (`setup.sh`, `assert.sh`, `teardown.sh` all TermLink-ready)
- Zero new dependencies (bash + termlink, both already required)
- Runner auto-discovers new test files (zero config)
- 34 scenarios cover the critical fw CLI paths that currently have zero E2E coverage
- ~2 min total runtime is CI-friendly
- Each test file is self-contained (~80-120 lines) and follows the proven pattern

Priority order for building:
1. `test-wf-task-lifecycle.sh` — most-used workflow, highest gap
2. `test-wf-git-traceability.sh` — commit hook enforcement is framework-critical
3. `test-wf-verification-gate.sh` — blocks task completion, must work
4. `test-wf-context-fabric.sh` — state management foundation
5. Remaining 6 in any order
