#!/usr/bin/env bats
# T-3048 — `fw test unit` and `fw test all` must skip, not hard-error, when the
# install ships no tests/unit/.
#
# Both legs are exercised against a synthetic FRAMEWORK_ROOT rather than by
# reading bin/fw, because the defect was behavioural: the code "looked fine"
# next to four sibling legs that happened to carry the guard it lacked.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    # A framework tree with everything fw needs to boot, but no tests/unit/.
    FAKE="$TEST_TEMP_DIR/fw"
    mkdir -p "$FAKE"
    cp -r "$FRAMEWORK_ROOT/bin" "$FRAMEWORK_ROOT/lib" "$FAKE/"
    cp "$FRAMEWORK_ROOT/VERSION" "$FAKE/" 2>/dev/null || true
    mkdir -p "$FAKE/tests/integration"
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT_ROOT/.context" "$PROJECT_ROOT/.tasks/active"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR:?}"
}

_run_leg() {
    # $1 = "unit" | "all". Run fw's test router against the synthetic tree.
    run env FRAMEWORK_ROOT="$FAKE" PROJECT_ROOT="$PROJECT_ROOT" NO_COLOR=1 \
        timeout 120 "$FAKE/bin/fw" test "$1"
}

@test "A2 — 'fw test unit' skips cleanly when tests/unit/ is absent" {
    command -v bats >/dev/null || skip "bats not installed"
    _run_leg unit
    [[ "$output" != *"does not exist"* ]]
    [[ "$output" != *"bats-gather-tests"* ]]
    [[ "$output" == *"No bats unit tests found"* ]]
}

@test "A2 — 'fw test all' skips cleanly when tests/unit/ is absent" {
    command -v bats >/dev/null || skip "bats not installed"
    _run_leg all
    [[ "$output" != *"does not exist"* ]]
    [[ "$output" == *"No bats unit tests found"* ]]
}

@test "A4 — the unguarded form really does hard-error (the guard is load-bearing)" {
    # Without this, the two greens above could be explained by bats never being
    # reached at all. Prove the pre-T-3048 call shape fails on the same tree.
    command -v bats >/dev/null || skip "bats not installed"
    run bats "$FAKE/tests/unit/"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "A3 — with tests/unit/ present and non-empty, the suite still runs" {
    command -v bats >/dev/null || skip "bats not installed"
    mkdir -p "$FAKE/tests/unit"
    cat > "$FAKE/tests/unit/zz_probe.bats" <<'EOF'
#!/usr/bin/env bats
@test "probe" { true; }
EOF
    _run_leg unit
    [[ "$output" == *"probe"* ]]
    [[ "$output" != *"No bats unit tests found"* ]]
}

@test "A1 — a tests/unit/ that exists but holds no .bats file also skips" {
    # The directory-only guard would pass here and hand bats an empty dir.
    command -v bats >/dev/null || skip "bats not installed"
    mkdir -p "$FAKE/tests/unit"
    _run_leg unit
    [[ "$output" == *"No bats unit tests found"* ]]
}
