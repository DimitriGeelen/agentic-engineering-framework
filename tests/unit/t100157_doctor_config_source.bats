#!/usr/bin/env bats
# T-100157 (OBS-085): do_doctor must source lib/config.sh before calling
# fw_consumer_yamls — otherwise every doctor run prints 'command not found'
# twice and the Consumer Projects checks silently no-op.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FW="$REPO_ROOT/bin/fw"
}

@test "do_doctor sources lib/config.sh before the first fw_consumer_yamls call" {
    local doctor_start src_line first_call
    doctor_start=$(grep -n '^do_doctor()' "$FW" | head -1 | cut -d: -f1)
    [ -n "$doctor_start" ]
    src_line=$(awk -v s="$doctor_start" 'NR>=s && /source "\$FRAMEWORK_ROOT\/lib\/config.sh"/ {print NR; exit}' "$FW")
    first_call=$(awk -v s="$doctor_start" 'NR>=s && /fw_consumer_yamls/ {print NR; exit}' "$FW")
    [ -n "$src_line" ]
    [ -n "$first_call" ]
    [ "$src_line" -lt "$first_call" ]
}

@test "lib/config.sh defines fw_consumer_yamls (contract pin)" {
    grep -q '^fw_consumer_yamls()' "$REPO_ROOT/lib/config.sh"
}
