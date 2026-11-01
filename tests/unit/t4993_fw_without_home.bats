#!/usr/bin/env bats
# T-4993 (050 field report, be.20): agent shells may run with no HOME. bin/fw runs under
# `set -euo pipefail`, so `fw upgrade` died mid-run and `fw doctor` died with
# "HOME: unbound variable". bin/fw now defaults HOME to the account's passwd home.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

@test "fw doctor --quick runs with HOME unset" {
    run env -u HOME "$FRAMEWORK_ROOT/bin/fw" doctor --quick
    ! echo "$output" | grep -q "unbound variable" || false
}

# Smoke only: the dry run stops before step 4c (where the field run died), so this passes
# with or without the fix. The real guarantee is the export test below: the default is set
# at the entry point and every subcommand and sourced lib inherits it.
@test "smoke: fw upgrade --dry-run runs with HOME unset" {
    C="$TEST_TEMP_DIR/consumer"
    mkdir -p "$C"
    git -C "$C" init -q
    run env -u HOME "$FRAMEWORK_ROOT/bin/fw" upgrade --dry-run "$C"
    ! echo "$output" | grep -q "unbound variable" || false
}

@test "the default is the passwd home and is exported to children" {
    want=$(getent passwd "$(id -un)" | cut -d: -f6)
    run env -u HOME bash -c "source <(sed -n '/^# T-4993/,/^fi$/p' '$FRAMEWORK_ROOT/bin/fw'); bash -c 'echo \"\$HOME\"'"
    [ "$output" = "$want" ]
}

@test "control: an explicitly set HOME is kept" {
    run env HOME=/tmp/explicit-home bash -c "source <(sed -n '/^# T-4993/,/^fi$/p' '$FRAMEWORK_ROOT/bin/fw'); echo \"\$HOME\""
    [ "$output" = "/tmp/explicit-home" ]
}
