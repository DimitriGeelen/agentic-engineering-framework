#!/usr/bin/env bats
# T-1628 (B-2 of T-1626) — per-hook fire / failure counters.
#
# Pins the contract that:
#   1. Every hook invocation increments .hook-counter[hookname]
#   2. Non-zero exits also increment .hook-failure-counter[hookname]
#   3. Files self-create on first fire — no init needed
#   4. Telemetry never blocks the hook (read-only fs / missing dir = silent 0)
#   5. Per-fire overhead stays under 5ms (T-1626 constraint)
#   6. The `bin/fw hook` dispatcher is wired to call fw_record_hook_fire
#
# Origin: T-1626 inception (ring20-dashboard 2026-04-30) — dozens of hook
# failures flowed past while framework reported clean. Telemetry is the
# foundation for B-3's threshold escalation; without these counters, the
# escalation work has nothing to read.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.context/working"
    # shellcheck disable=SC1091
    source "$FRAMEWORK_ROOT/lib/hook-telemetry.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "hook-telemetry.sh contains a T-1628 marker" {
    grep -q "T-1628" "$FRAMEWORK_ROOT/lib/hook-telemetry.sh"
}

@test "bin/fw dispatcher invokes fw_record_hook_fire" {
    grep -q "fw_record_hook_fire" "$FRAMEWORK_ROOT/bin/fw"
}

@test "bin/fw sources lib/hook-telemetry.sh" {
    grep -q "hook-telemetry.sh" "$FRAMEWORK_ROOT/bin/fw"
}

# ---- Behavioural tests ----

@test "first fire creates .hook-counter with count=1" {
    [ ! -f "$PROJECT_ROOT/.context/working/.hook-counter" ]
    fw_record_hook_fire "check-active-task" 0
    [ -f "$PROJECT_ROOT/.context/working/.hook-counter" ]
    grep -q '^check-active-task=1$' "$PROJECT_ROOT/.context/working/.hook-counter"
}

@test "second fire increments the same hook" {
    fw_record_hook_fire "check-tier0" 0
    fw_record_hook_fire "check-tier0" 0
    grep -q '^check-tier0=2$' "$PROJECT_ROOT/.context/working/.hook-counter"
}

@test "non-zero exit also creates .hook-failure-counter" {
    [ ! -f "$PROJECT_ROOT/.context/working/.hook-failure-counter" ]
    fw_record_hook_fire "checkpoint" 1
    [ -f "$PROJECT_ROOT/.context/working/.hook-failure-counter" ]
    grep -q '^checkpoint=1$' "$PROJECT_ROOT/.context/working/.hook-failure-counter"
    grep -q '^checkpoint=1$' "$PROJECT_ROOT/.context/working/.hook-counter"
}

@test "exit 0 does NOT touch .hook-failure-counter" {
    fw_record_hook_fire "block-plan-mode" 0
    [ ! -f "$PROJECT_ROOT/.context/working/.hook-failure-counter" ]
}

@test "multiple hooks tracked independently" {
    fw_record_hook_fire "check-active-task" 0
    fw_record_hook_fire "check-tier0" 0
    fw_record_hook_fire "check-active-task" 0
    grep -q '^check-active-task=2$' "$PROJECT_ROOT/.context/working/.hook-counter"
    grep -q '^check-tier0=1$' "$PROJECT_ROOT/.context/working/.hook-counter"
}

@test "exit 2 (block) increments failure counter" {
    fw_record_hook_fire "check-tier0" 2
    grep -q '^check-tier0=1$' "$PROJECT_ROOT/.context/working/.hook-failure-counter"
}

@test "fw_hook_counter_get reads current values" {
    fw_record_hook_fire "checkpoint" 0
    fw_record_hook_fire "checkpoint" 0
    fw_record_hook_fire "checkpoint" 1
    [ "$(fw_hook_counter_get fires checkpoint)" = "3" ]
    [ "$(fw_hook_counter_get failures checkpoint)" = "1" ]
}

@test "fw_hook_counter_get returns 0 for unknown hook" {
    [ "$(fw_hook_counter_get fires nonexistent)" = "0" ]
    [ "$(fw_hook_counter_get failures nonexistent)" = "0" ]
}

@test "telemetry returns 0 silently when working dir is missing" {
    rm -rf "$PROJECT_ROOT/.context/working"
    run fw_record_hook_fire "check-active-task" 1
    [ "$status" -eq 0 ]
}

@test "telemetry returns 0 silently when working dir is read-only" {
    chmod 555 "$PROJECT_ROOT/.context/working"
    run fw_record_hook_fire "check-active-task" 1
    [ "$status" -eq 0 ]
    chmod 755 "$PROJECT_ROOT/.context/working"
}

@test "missing-hook degrade-to-allow path records as failure (T-1626 witness)" {
    # The exact T-1626 scenario: hook is configured but not found. Pre-T-1628
    # this exited 0 silently. Now it must increment .hook-failure-counter
    # under the configured hook name so B-3 / fw doctor see the drift.
    PROJECT_ROOT="$TEST_TEMP_DIR" run "$FRAMEWORK_ROOT/bin/fw" hook bogus-hook-name-for-T1628
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/.context/working/.hook-failure-counter" ]
    grep -q '^bogus-hook-name-for-T1628=1$' "$TEST_TEMP_DIR/.context/working/.hook-failure-counter"
    grep -q '^bogus-hook-name-for-T1628=1$' "$TEST_TEMP_DIR/.context/working/.hook-counter"
}

@test "performance: 1000 fires under 5000ms (<5ms each, T-1626 budget)" {
    # Run in a subshell to avoid bats per-call instrumentation skewing the
    # wall-clock. The actual hot path is what `bin/fw hook` will exercise —
    # one fork to bash, then N fires inside that single bash session.
    local elapsed_ms
    elapsed_ms=$(PROJECT_ROOT="$PROJECT_ROOT" bash -c '
        source "'"$FRAMEWORK_ROOT"'/lib/hook-telemetry.sh"
        start=$(date +%s%N)
        for _ in $(seq 1 1000); do
            fw_record_hook_fire "check-active-task" 0
        done
        end=$(date +%s%N)
        echo $(( (end - start) / 1000000 ))
    ')
    echo "1000 fires took ${elapsed_ms}ms (avg $((elapsed_ms * 1000 / 1000))us each)" >&2
    [ "$elapsed_ms" -lt 5000 ]
    grep -q '^check-active-task=1000$' "$PROJECT_ROOT/.context/working/.hook-counter"
}
