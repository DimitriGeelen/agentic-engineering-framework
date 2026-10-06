#!/usr/bin/env bats
# T-1434: fw doctor must detect drift between framework source
# (lib/*.sh, agents/context/*.sh, agents/task-create/*.sh) and the
# vendored copies under .agentic-framework/. This prevents the class
# of bug that T-1432 and T-1433 hit: source edits that consumers miss
# because the vendored copy stayed stale.
#
# T-3950: the check runs against a THROWAWAY framework root. This file used to run the whole
# `fw doctor` in the live repo and mutate the live .agentic-framework/lib/colors.sh. Under the
# parallel suite one doctor run took 275 s, and the "in sync" test failed whenever the live
# repo had real, transient drift (a source file edited and not yet vendored) — a red that said
# nothing about the check. Check 2b is lifted from bin/fw and run on a fixture: hermetic, fast.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FIX="$TEST_TEMP_DIR/fw"
    mkdir -p "$FIX/lib" "$FIX/.agentic-framework/lib"
    printf '#!/bin/bash\n# colours\nRED=x\n' > "$FIX/lib/colors.sh"
    cp "$FIX/lib/colors.sh" "$FIX/.agentic-framework/lib/colors.sh"
    CHECK="$(awk '/# Check 2b \(T-1434\): Vendored-source drift/{p=1} p{print} p&&/^    fi$/{exit}' \
        "$FRAMEWORK_ROOT/bin/fw")"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_check() {   # run Check 2b with FRAMEWORK_ROOT = PROJECT_ROOT = the fixture
    FRAMEWORK_ROOT="$FIX" PROJECT_ROOT="$FIX" bash -c "
        GREEN=''; YELLOW=''; NC=''
        _c() { $CHECK
        }
        _c"
}

@test "T-3950: Check 2b was found in bin/fw" {
    [[ "$CHECK" == *"No vendored-source drift"* ]]
}

@test "fw doctor: reports 'No vendored-source drift' when in sync" {
    run _check
    [ "$status" -eq 0 ]
    [[ "$output" == *"No vendored-source drift"* ]]
}

@test "fw doctor: reports 'Vendored-source drift' when a vendored file diverges" {
    echo "# T-1434 drift sentinel — should be detected" >> "$FIX/.agentic-framework/lib/colors.sh"
    run _check
    [[ "$output" == *"Vendored-source drift"* ]]
    [[ "$output" == *"file(s) out of sync"* ]]
    [[ "$output" == *"lib/colors.sh"* ]]
}

@test "fw doctor: drift output names Run: fw vendor" {
    echo "# T-1434 drift sentinel" >> "$FIX/.agentic-framework/lib/colors.sh"
    run _check
    [[ "$output" == *"Run: fw vendor"* ]]
}
