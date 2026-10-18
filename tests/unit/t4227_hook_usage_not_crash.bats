#!/usr/bin/env bats
# T-4227: a hook's usage error is not a hook crash, and the crash log can be
# acknowledged back to zero.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.context/working"
    LOG="$PROJ/.context/working/.hook-crashes.log"
}

teardown() {
    rm -rf "$PROJ"
}

@test "checkpoint.sh with no argument: usage, no HOOK CRASHED, crash log untouched" {
    run env PROJECT_ROOT="$PROJ" bash "$REPO/agents/context/checkpoint.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: checkpoint.sh"* ]]
    [[ "$output" != *"HOOK CRASHED"* ]]
    [ ! -s "$LOG" ]
}

@test "checkpoint.sh with an unknown argument: no HOOK CRASHED, crash log untouched" {
    run env PROJECT_ROOT="$PROJ" bash "$REPO/agents/context/checkpoint.sh" bogus
    [ "$status" -eq 1 ]
    [[ "$output" != *"HOOK CRASHED"* ]]
    [ ! -s "$LOG" ]
}

@test "a genuine crash (unmarked exit 1) still announces and logs" {
    cat > "$PROJ/crashy.sh" <<EOF
source "$REPO/lib/config.sh"
fw_hook_crash_trap "crashy"
false || exit 1
EOF
    run env PROJECT_ROOT="$PROJ" bash "$PROJ/crashy.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"HOOK CRASHED: crashy"* ]]
    grep -q "CRASH: crashy exit=1" "$LOG"
}

@test "a policy block (exit 2) is neither a crash nor logged" {
    cat > "$PROJ/blocky.sh" <<EOF
source "$REPO/lib/config.sh"
fw_hook_crash_trap "blocky"
exit 2
EOF
    run env PROJECT_ROOT="$PROJ" bash "$PROJ/blocky.sh"
    [ "$status" -eq 2 ]
    [[ "$output" != *"HOOK CRASHED"* ]]
    [ ! -s "$LOG" ]
}

@test "acknowledge empties the live log, keeps history, count returns to zero" {
    printf '[2026-10-18T00:00:00Z] CRASH: a exit=1\n[2026-10-18T00:00:01Z] CRASH: b exit=1\n' > "$LOG"
    run env PROJECT_ROOT="$PROJ" bash "$REPO/lib/hook-crashes.sh" count
    [ "$output" = "2" ]
    run env PROJECT_ROOT="$PROJ" bash "$REPO/lib/hook-crashes.sh" acknowledge
    [ "$status" -eq 0 ]
    [[ "$output" == *"Acknowledged 2"* ]]
    [ ! -s "$LOG" ]
    grep -q "CRASH: a exit=1" "$PROJ/.context/working/.hook-crashes.acknowledged.log"
    run env PROJECT_ROOT="$PROJ" bash "$REPO/lib/hook-crashes.sh" count
    [ "$output" = "0" ]
    run env PROJECT_ROOT="$PROJ" bash "$REPO/lib/hook-crashes.sh" acknowledge
    [ "$status" -eq 0 ]
    [[ "$output" == *"No unacknowledged"* ]]
}
