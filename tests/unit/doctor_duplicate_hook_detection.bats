#!/usr/bin/env bats
# T-1480 — `fw doctor` surfaces the same duplicate-hook scan as T-1479's
# `fw upgrade` check. Read-only diagnostic so users see the overlap on
# every health check, not only when upgrading.

load ../test_helper

setup() {
    export FW_DOCTOR_HOOK_EXERCISE=0  # T-4523: the probe runs every hook against this checkout
    export FW_DOCTOR_SMOKE=0  # T-3933: never sweep the live Watchtower from a test
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "bin/fw contains the duplicate-hook detection block (T-1480)" {
    grep -q "Duplicate framework hook" "$FRAMEWORK_ROOT/bin/fw"
}

@test "bin/fw references \$HOME/.claude/settings.json for the doctor scan (T-1480)" {
    grep -q '\$HOME/.claude/settings.json' "$FRAMEWORK_ROOT/bin/fw"
}

@test "bin/fw doctor emits the OBS-023 cause hint when duplicates found (T-1480)" {
    grep -q "cause of OBS-023" "$FRAMEWORK_ROOT/bin/fw"
}

@test "bin/fw parses (bash -n) (T-1480)" {
    bash -n "$FRAMEWORK_ROOT/bin/fw"
}

# ---- Smoke: doctor runs end-to-end ----

@test "fw doctor runs without erroring (smoke, T-1480)" {
    cd "$FRAMEWORK_ROOT"
    # Don't care about exit code (doctor returns non-zero when warnings exist),
    # only that it produces output and doesn't bash-error.
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    [ -n "$output" ]
    # Should never produce a python traceback from the dedup helper
    ! echo "$output" | grep -qE 'Traceback \(most recent call last\):'
}

# ---- Behavioural via the SHIPPED python helper ----
# T-4380: the helper is cut out of bin/fw (the dup_pairs python block); this test
# used to run a copy of it, which stayed green when the shipped `out.add` was
# disabled.

@test "behavioural: doctor's helper reports overlap when both files have framework hooks" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":".agentic-framework/bin/fw hook pre-compact"}]}]}}
EOF
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    awk '/dup_pairs=\$\(USER_FILE=.* python3 -c "$/{f=1; next} f && /^" 2>\/dev\/null/{exit} f' \
        "$FRAMEWORK_ROOT/bin/fw" > helper.py
    [ -s helper.py ]
    grep -q 'def fw_hooks' helper.py
    out=$(USER_FILE=user.json PROJ_FILE=proj.json python3 helper.py)
    [ "$out" = "PreCompact:pre-compact" ]
}
