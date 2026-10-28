#!/usr/bin/env bats
# T-4809 (1409 dauerlauf-1 pickup F5) — every claude-fw launch writes
# `{"event":"start","reason":"armed",...,"detail":"... armed=no ..."}` to
# continuous-run.jsonl: `reason=armed` means "the supervisor started", the
# continuous-mode state is the `armed=yes|no` token in detail. audit.sh's
# check_continuous_run_turn_driver (G-099) treated every start/iterate as
# "wrapper ARMED" and WARNed "wrapper last recorded ARMED but the turn driver is
# not" for every ordinary interactive session. fw doctor's twin was fixed by
# T-4358; the audit cron copy was not.

load ../test_helper

AUDIT_SH="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
    LEDGER="$TEST_TEMP_DIR/.context/working/continuous-run.jsonl"
    # The check under test, extracted verbatim from audit.sh (sourcing the whole
    # agent would run every audit section).
    FN="$TEST_TEMP_DIR/check.sh"
    sed -n '/^check_continuous_run_turn_driver() {$/,/^}$/p' "$AUDIT_SH" > "$FN"
    [ -s "$FN" ]
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

run_check() {
    run bash -c "
        warn() { echo \"WARN: \$1 | \$2\"; }
        PROJECT_ROOT='$TEST_TEMP_DIR'; FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        source '$FN'
        check_continuous_run_turn_driver"
}

start_line() {  # $1 = yes|no
    printf '{"ts":"2026-10-27T10:00:00Z","event":"start","reason":"armed","restart_count":0,"wrapper_pid":1,"detail":"restart=enabled max_restarts=5 window=3600s armed=%s termlink=0"}\n' "$1"
}

@test "start with armed=no, never armed: no G-099 WARN" {
    start_line no > "$LEDGER"
    run_check
    [ "$status" -eq 0 ]
    [[ "$output" != *"last recorded ARMED"* ]] || { echo "$output"; false; }
}

@test "start with armed=no, deliberately disarmed: no G-099 WARN" {
    start_line no > "$LEDGER"
    printf 'enabled: false\ndisarmed_reason: test\n' > "$TEST_TEMP_DIR/.context/working/.continuous-mode.yaml"
    run_check
    [[ "$output" != *"last recorded ARMED"* ]] || { echo "$output"; false; }
}

@test "iterate after an unarmed start, never armed: no G-099 WARN" {
    start_line no > "$LEDGER"
    printf '{"ts":"2026-10-27T11:00:00Z","event":"iterate","reason":"budget","restart_count":1,"wrapper_pid":1}\n' >> "$LEDGER"
    run_check
    [[ "$output" != *"last recorded ARMED"* ]] || { echo "$output"; false; }
}

@test "T-4873: start with armed=yes and no readable continuous state still WARNs" {
    start_line yes > "$LEDGER"
    rm -f "$TEST_TEMP_DIR/.context/working/.continuous-mode.yaml"
    run_check
    [[ "$output" == *"WARN: Continuous-run wrapper last recorded ARMED but the turn driver is not"* ]] || { echo "$output"; false; }
}

@test "T-4873: iterate after an armed=yes start with no readable state still WARNs" {
    start_line yes > "$LEDGER"
    printf '{"ts":"2026-10-27T11:00:00Z","event":"iterate","reason":"budget","restart_count":1,"wrapper_pid":1}\n' >> "$LEDGER"
    rm -f "$TEST_TEMP_DIR/.context/working/.continuous-mode.yaml"
    run_check
    [[ "$output" == *"WARN: Continuous-run wrapper last recorded ARMED but the turn driver is not"* ]] || { echo "$output"; false; }
}

@test "CONTROL: start with armed=yes and an armed run that lapsed still WARNs" {
    start_line yes > "$LEDGER"
    printf 'enabled: true\ncurrent_iteration: 3\nmax_iterations: 3\n' > "$TEST_TEMP_DIR/.context/working/.continuous-mode.yaml"
    run_check
    [[ "$output" == *"WARN: Continuous-run wrapper last recorded ARMED but the turn driver is not"* ]] || { echo "$output"; false; }
}

@test "the shipped wrapper records the real armed state in its start detail" {
    grep -A1 '^_record_loop_event start armed' "$FRAMEWORK_ROOT/bin/claude-fw" \
        | grep -q 'armed=$(_continuous_armed && echo yes || echo no)'
}
