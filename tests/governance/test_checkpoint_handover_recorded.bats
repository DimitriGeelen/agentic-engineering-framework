#!/usr/bin/env bats
# Regression: the budget-critical auto-handover (checkpoint.sh, T-179) records its
# outcome durably, and fw doctor surfaces a failed one (T-2507, OBS-090).
#
# Origin (T-2507 audit): pre-compact.sh writes [pre-compact] Handover generated|FAILED
# to .compact-log and fw doctor Check 5d surfaces it (T-2506). The OTHER memory-capture
# path — checkpoint.sh's budget-critical auto-handover, the one that fires just before
# an auto-restart — only echoed "Failed" to stderr. Not-even-recorded, on the most
# catastrophic memory-loss path. Now it writes [checkpoint] Handover generated|FAILED
# to the same .compact-log, and Check 5d's grep is broadened to catch both markers.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"
CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_doctor() {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' doctor 2>&1"
}

# --- checkpoint.sh records the outcome durably (was echo-only) --------------

@test "T-2507: checkpoint.sh writes a durable [checkpoint] Handover line to .compact-log on BOTH branches" {
    run grep -Eq '\[checkpoint\] \[auto\] Handover generated' "$CHECKPOINT"
    [ "$status" -eq 0 ]
    run grep -Eq '\[checkpoint\] \[auto\] Handover FAILED' "$CHECKPOINT"
    [ "$status" -eq 0 ]
}

@test "T-2507: checkpoint.sh branches on the handover's TRUE rc (capture to file, not pipe-to-tail)" {
    # The old form `handover.sh --commit 2>&1 | tail -5 >&2` masked the rc without
    # pipefail; the fix redirects to a capture file and tests the direct exit code.
    run grep -Eq 'handover\.sh" --commit >"\$_ah_capture" 2>&1' "$CHECKPOINT"
    [ "$status" -eq 0 ]
    run grep -Eq 'handover\.sh" --commit 2>&1 \| tail' "$CHECKPOINT"
    [ "$status" -ne 0 ]
}

# --- doctor surfaces a failed budget-critical handover ----------------------

@test "T-2507: fw doctor WARNs on a failed [checkpoint] (budget-critical) handover" {
    printf '[checkpoint] [auto] Handover FAILED at 2026-07-06T10:00:00Z — see .checkpoint.handover.stderr\n' \
        > "$PROJECT_ROOT/.context/working/.compact-log"
    _run_doctor
    [[ "$output" == *"budget-critical auto-handover FAILED"* ]]
}

@test "T-2507: fw doctor OK line names the source on a successful [checkpoint] handover" {
    printf '[checkpoint] [auto] Handover generated at 2026-07-06T10:00:00Z\n' \
        > "$PROJECT_ROOT/.context/working/.compact-log"
    _run_doctor
    [[ "$output" != *"FAILED"* ]]
    [[ "$output" == *"Last auto-handover succeeded (budget-critical auto-handover)"* ]]
}

# --- no regression to the T-2506 pre-compact leg ----------------------------

@test "T-2507: fw doctor still WARNs on a failed [pre-compact] handover (broadened grep, no regression)" {
    printf '[pre-compact] [manual] Handover FAILED (rc=126) at 2026-07-06T09:00:00Z\n' \
        > "$PROJECT_ROOT/.context/working/.compact-log"
    _run_doctor
    [[ "$output" == *"pre-compact handover FAILED"* ]]
}

@test "T-2507: fw doctor reports the LAST auto-handover when both paths logged" {
    {
        printf '[pre-compact] [manual] Handover FAILED (rc=126) at 2026-07-06T09:00:00Z\n'
        printf '[checkpoint] [auto] Handover generated at 2026-07-06T10:00:00Z\n'
    } > "$PROJECT_ROOT/.context/working/.compact-log"
    _run_doctor
    # Most recent entry is the checkpoint success → OK, not the earlier pre-compact FAIL.
    [[ "$output" == *"Last auto-handover succeeded (budget-critical auto-handover)"* ]]
    [[ "$output" != *"FAILED"* ]]
}
