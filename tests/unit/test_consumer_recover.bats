#!/usr/bin/env bats
# T-2235 — fw consumer-recover wrapper (authorised under T-2233 GO).
#
# Tests cover the 8 cases in docs/reports/T-2233-consumer-recover-design.md §8.
# Transport is mocked via PATH shadowing — no real SSH or TermLink calls.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # PROJECT_ROOT must NOT leak through to bin/fw — we run against a fresh test root.
    unset PROJECT_ROOT
    # Mock-transport recording — every test starts with a clean call log.
    export CR_MOCK_LOG="$TEST_TEMP_DIR/transport.log"
    : > "$CR_MOCK_LOG"
    # Install mock ssh + mock termlink shadowing the real ones.
    mkdir -p "$TEST_TEMP_DIR/bin"
    cat > "$TEST_TEMP_DIR/bin/ssh" <<'MOCK'
#!/bin/bash
# Mock ssh: log every invocation, simulate the consumer-side probes.
# Sentinel probe form:  ssh HOST "test -s '...'"  → exit 0 if SENTINEL_PRESENT=1.
# Project-valid probe:  ssh HOST "test -f '....framework.yaml'" → 0 if PROJECT_VALID=1 (default).
# Anything else (the recovery heredoc) → exit 0 (success).
echo "ssh $*" >> "${CR_MOCK_LOG:-/dev/null}"
for arg in "$@"; do
    case "$arg" in
        *"test -s"*) [ "${SENTINEL_PRESENT:-0}" = "1" ] && exit 0 || exit 1 ;;
        *"test -f"*) [ "${PROJECT_VALID:-1}" = "1" ] && exit 0 || exit 1 ;;
    esac
done
exit 0
MOCK
    chmod +x "$TEST_TEMP_DIR/bin/ssh"
    cat > "$TEST_TEMP_DIR/bin/termlink" <<'MOCK'
#!/bin/bash
# T-2236: enforce the real CLI shape so future drift fails tests.
# Real shapes:
#   termlink remote list <HUB>              (1 positional after subcmd)
#   termlink remote exec <HUB> <SESSION> <CMD...>  (≥3 positional after subcmd)
echo "termlink $*" >> "${CR_MOCK_LOG:-/dev/null}"
case "$1" in
    remote)
        case "$2" in
            list)
                # Must have HUB arg
                if [ -z "${3:-}" ]; then
                    echo "MOCK error: 'termlink remote list' requires <HUB>" >&2
                    exit 64
                fi
                if [ "${TERMLINK_HAS_HOST:-0}" = "1" ]; then
                    # Emit header + one ready session row in real format
                    echo "ID             NAME             FP                STATE          PID      TAGS"
                    echo "----"
                    echo "tl-mockready   targetsession   abc123             ready          12345    project=test"
                fi
                exit 0
                ;;
            exec)
                # Must have HUB + SESSION + CMD (≥3 positional after 'exec')
                if [ -z "${5:-}" ]; then
                    echo "MOCK error: 'termlink remote exec' requires <HUB> <SESSION> <COMMAND>" >&2
                    exit 64
                fi
                # $3 = HUB, $4 = SESSION, $5+ = COMMAND
                shift 4  # drop "remote exec HUB SESSION"
                for arg in "$@"; do
                    case "$arg" in
                        *"test -s"*) [ "${SENTINEL_PRESENT:-0}" = "1" ] && exit 0 || exit 1 ;;
                        *"test -f"*) [ "${PROJECT_VALID:-1}" = "1" ] && exit 0 || exit 1 ;;
                    esac
                done
                exit 0
                ;;
        esac
        ;;
esac
exit 0
MOCK
    chmod +x "$TEST_TEMP_DIR/bin/termlink"
    export PATH="$TEST_TEMP_DIR/bin:$PATH"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ============================================================================
# Case 1 — dry-run prints recipe with all the load-bearing parts
# ============================================================================

@test "dry-run prints recipe header and key recipe parts" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" testhost /tmp/foo
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DRY RUN"
    echo "$output" | grep -q "Host:          testhost"
    echo "$output" | grep -q "Project path:  /tmp/foo"
    # Load-bearing bits of the recipe:
    echo "$output" | grep -q "mktemp -d /tmp/fw-fresh"
    echo "$output" | grep -q "git clone --depth 1"
    echo "$output" | grep -q 'env FRAMEWORK_ROOT='
    echo "$output" | grep -q 'PROJECT_ROOT='
    # Recipe invokes the freshly-cloned fw via "$TMPDIR/bin/fw" upgrade / doctor
    echo "$output" | grep -qE 'bin/fw" upgrade'
    echo "$output" | grep -qE 'bin/fw" doctor'
    echo "$output" | grep -q "To execute, re-run with --apply"
}

# ============================================================================
# Case 2 — dry-run substitutes positional values correctly
# ============================================================================

@test "dry-run substitutes host, project path, and upstream into the recipe" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        myhost.example /srv/myconsumer \
        --upstream https://example.test/repo.git
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'PROJECT_PATH="/srv/myconsumer"'
    echo "$output" | grep -q 'UPSTREAM="https://example.test/repo.git"'
    echo "$output" | grep -q "Host:          myhost.example"
}

# ============================================================================
# Case 3 — sentinel detected → exit 2 + redirect message
# ============================================================================

@test "sentinel present causes exit 2 with redirect to plain fw upgrade" {
    run env SENTINEL_PRESENT=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        testhost /tmp/foo --upstream https://test/repo.git
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "post-T-2232"
    echo "$output" | grep -q "Use plain fw upgrade"
}

# ============================================================================
# Case 4 — missing host → exit 1 + usage shown
# ============================================================================

@test "missing host argument exits 1 and shows usage" {
    run bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage:"
}

# ============================================================================
# Case 5 — --keep-temp omits the trap cleanup line
# ============================================================================

@test "--keep-temp omits the trap rm -rf line" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        testhost /tmp/foo --upstream https://test/repo.git --keep-temp
    [ "$status" -eq 0 ]
    [[ "$output" != *"trap 'rm -rf"* ]]
    echo "$output" | grep -q "keep-temp: tempdir left on host"
}

@test "default (no --keep-temp) includes the trap rm -rf line" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        testhost /tmp/foo --upstream https://test/repo.git
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "trap 'rm -rf"
}

# ============================================================================
# Case 6 — --upstream URL overrides auto-detect
# ============================================================================

@test "--upstream overrides auto-detected URL" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        testhost /tmp/foo --upstream https://override.test/repo.git
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Upstream URL:  https://override.test/repo.git"
}

@test "--upstream strips embedded credentials" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        testhost /tmp/foo --upstream "https://SECRETTOKEN@host.test/repo.git"
    [ "$status" -eq 0 ]
    [[ "$output" != *"SECRETTOKEN"* ]]
    echo "$output" | grep -q "https://host.test/repo.git"
}

# ============================================================================
# Case 7 — --via ssh forces SSH even if TermLink would resolve
# ============================================================================

@test "--via ssh forces SSH transport even when TermLink has the host" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 TERMLINK_HAS_HOST=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        targethost /tmp/foo --upstream https://test/repo.git --via ssh
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Transport:     ssh"
}

@test "--via termlink forces TermLink transport (with --session)" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        testhost /tmp/foo --upstream https://test/repo.git --via termlink --session tl-test
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Transport:     termlink"
}

@test "--via termlink auto-discovers session when --session not given" {
    # TERMLINK_HAS_HOST=1 makes the mock list a ready session row
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 TERMLINK_HAS_HOST=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        targethost /tmp/foo --upstream https://test/repo.git --via termlink
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Transport:     termlink"
}

@test "--via termlink fails when no ready session and no --session" {
    # TERMLINK_HAS_HOST=0 → mock lists empty session table → auto-discover empty
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        testhost /tmp/foo --upstream https://test/repo.git --via termlink
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "no ready session"
}

@test "--via with invalid value exits 1" {
    run bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        testhost /tmp/foo --via bogus --upstream https://test/repo.git
    [ "$status" -eq 1 ]
    echo "$output" | grep -q -- "--via must be ssh or termlink"
}

# ============================================================================
# Case 8 — --json emits structured outcome
# ============================================================================

@test "--json on dry-run emits envelope with host/project/upstream/exit_code" {
    run env FW_CONSUMER_RECOVER_NO_PROBE=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        myhost /srv/myproj --upstream https://test/repo.git --json
    [ "$status" -eq 0 ]
    # The JSON is emitted to stdout after the dry-run recipe.
    echo "$output" | grep -q '"host": "myhost"'
    echo "$output" | grep -q '"project_path": "/srv/myproj"'
    echo "$output" | grep -q '"upstream": "https://test/repo.git"'
    echo "$output" | grep -q '"outcome": "dry-run"'
    echo "$output" | grep -q '"exit_code": 0'
}

@test "--json on sentinel-refuse emits refused-post-t2232 outcome" {
    run env SENTINEL_PRESENT=1 \
        bash "$FRAMEWORK_ROOT/lib/consumer-recover.sh" \
        targethost /tmp/foo --upstream https://test/repo.git --json
    [ "$status" -eq 2 ]
    echo "$output" | grep -q '"outcome": "refused-post-t2232"'
    echo "$output" | grep -q '"exit_code": 2'
}

# ============================================================================
# Smoke: dispatcher wires the verb (run as `fw consumer-recover --help`)
# ============================================================================

@test "fw consumer-recover --help routes to do_consumer_recover" {
    run bin/fw consumer-recover --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "fw consumer-recover"
    echo "$output" | grep -q "Authorised: T-2233 GO"
}
