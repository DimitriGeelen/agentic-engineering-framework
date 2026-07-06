#!/usr/bin/env bats
# Regression: pre-compact handover survives a missing exec bit, and a failed
# capture is surfaced by fw doctor (T-2506).
#
# Origin (S-2026-0706 memory-loss RCA): the vendored handover.sh lost its exec
# bit; pre-compact.sh invoked it by BARE EXEC, so it died with `Permission
# denied` (rc≈126); LATEST.md was never repointed; every /compact reinjected a
# STALE handover. The failure was logged to .compact-log but surfaced nowhere.
#
# Fix has two legs, each pinned below:
#   AC1/AC2 — pre-compact.sh AND checkpoint.sh invoke handover.sh via the `bash`
#             interpreter (exec-bit-immune). Mechanism proven + both call sites pinned.
#   AC3     — fw doctor WARNs when the last pre-compact handover FAILED.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"
PRECOMPACT="$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- AC1/AC2: exec-bit immunity ---------------------------------------------

@test "T-2506: the mechanism — a non-executable script runs via bash, not via bare exec" {
    local script="$TEST_TEMP_DIR/dummy_handover.sh"
    printf '#!/bin/bash\necho ran\n' > "$script"
    chmod -x "$script"          # strip the exec bit, exactly like the vendored copy

    # Bare exec MUST fail (this is the bug that dropped memory)...
    run "$script"
    [ "$status" -ne 0 ]

    # ...but interpreter invocation (the fix) MUST succeed.
    run bash "$script"
    [ "$status" -eq 0 ]
    [ "$output" = "ran" ]
}

@test "T-2506: pre-compact.sh invokes handover.sh via bash (not bare exec)" {
    # If someone reverts to `"$FRAMEWORK_ROOT/.../handover.sh"` bare exec, this fails.
    run grep -Eq 'bash[[:space:]]+"\$FRAMEWORK_ROOT/agents/handover/handover\.sh"' "$PRECOMPACT"
    [ "$status" -eq 0 ]
    # And no bare-exec form of the invocation remains.
    run grep -Eq '^[[:space:]]*"\$FRAMEWORK_ROOT/agents/handover/handover\.sh"' "$PRECOMPACT"
    [ "$status" -ne 0 ]
}

@test "T-2506: checkpoint.sh auto-handover invokes handover.sh via bash (not bare exec)" {
    run grep -Eq 'bash[[:space:]]+"\$FRAMEWORK_ROOT/agents/handover/handover\.sh"' "$CHECKPOINT"
    [ "$status" -eq 0 ]
    # The bare-exec form is `timeout "$_ah_total_timeout" "$FRAMEWORK_ROOT/..."` —
    # the timeout var quote directly abutting the script quote, with no `bash` between.
    run grep -Eq '_ah_total_timeout"[[:space:]]+"\$FRAMEWORK_ROOT/agents/handover/handover\.sh"' "$CHECKPOINT"
    [ "$status" -ne 0 ]
}

# --- AC3: doctor surfaces a failed capture ----------------------------------

@test "T-2506: fw doctor WARNs when the last pre-compact handover FAILED" {
    printf '[pre-compact] [manual] Handover FAILED (rc=126) at 2026-07-06T09:00:49Z — see .pre-compact.handover.stderr\n' \
        > "$PROJECT_ROOT/.context/working/.compact-log"

    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' doctor 2>&1"
    [[ "$output" == *"Last pre-compact handover FAILED"* ]]
}

@test "T-2506: fw doctor does NOT warn when the last pre-compact handover succeeded" {
    printf '[pre-compact] [manual] Handover generated at 2026-07-06T09:00:49Z\n' \
        > "$PROJECT_ROOT/.context/working/.compact-log"

    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' doctor 2>&1"
    [[ "$output" != *"FAILED"* ]]
    # T-2507 generalised the OK line to "Last auto-handover succeeded (<source>)".
    [[ "$output" == *"Last auto-handover succeeded"* ]]
}

@test "T-2506: fw doctor is silent about pre-compact when there is no compact-log" {
    # Fresh project with no .compact-log — neither OK nor WARN line for this check.
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' doctor 2>&1"
    [[ "$output" != *"Last pre-compact handover"* ]]
}
