#!/usr/bin/env bats
# T-4219: `fw test lint` exited 1 in every vendored consumer — the Silent-Skip lint
# scanned <framework>/tests/, which a vendored copy does not ship, and read the
# empty scan as "not a pass". Missing tests/ is NOT APPLICABLE; a present tests/
# keeps the old behaviour.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    ROOT="$TEST_TEMP_DIR/fw"
    mkdir -p "$ROOT/tools"
    cp "$FRAMEWORK_ROOT/tools/bats-silent-skip-lint.py" "$ROOT/tools/"
    # shellcheck source=/dev/null
    source "$FRAMEWORK_ROOT/lib/silent-skip-lint.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-4219: vendored copy without tests/ is NOT APPLICABLE and passes" {
    run fw_silent_skip_lint "$ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT APPLICABLE"* ]]
}

@test "T-4219: tests/ with an unconditional skip still fails" {
    mkdir -p "$ROOT/tests/unit"
    printf '#!/usr/bin/env bats\n@test "x" {\n    skip\n    true\n}\n' > "$ROOT/tests/unit/a.bats"
    run fw_silent_skip_lint "$ROOT"
    [ "$status" -ne 0 ]
}

@test "T-4219: tests/ with only a legitimately guarded skip passes" {
    mkdir -p "$ROOT/tests/unit"
    # The linter needs at least one skip call site to count a scan as examined;
    # an optional-dependency guard is the legitimate shape.
    printf '#!/usr/bin/env bats\n@test "x" {\n    command -v some-optional-tool >/dev/null || skip "some-optional-tool not installed"\n    true\n}\n' > "$ROOT/tests/unit/a.bats"
    run fw_silent_skip_lint "$ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no silent skips"* ]]
}

@test "T-4219: an empty tests/ (scan examined nothing) is not a pass" {
    mkdir -p "$ROOT/tests"
    run fw_silent_skip_lint "$ROOT"
    [ "$status" -ne 0 ]
}

@test "T-4219: no linter in the copy is a no-op pass (unchanged)" {
    rm "$ROOT/tools/bats-silent-skip-lint.py"
    run fw_silent_skip_lint "$ROOT"
    [ "$status" -eq 0 ]
}
