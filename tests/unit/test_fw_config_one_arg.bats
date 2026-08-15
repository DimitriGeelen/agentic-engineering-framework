#!/usr/bin/env bats
# fw_config with one argument — T-3013 (OBS-255).
#
# `local default="$2"` was unguarded, so `fw_config KEY` was fatal under `set -u`,
# which bin/fw sets globally (`set -euo pipefail`). The failure is silent in a way
# that matters: an unbound-variable exit is NOT a command failure, so the idiomatic
# `|| echo <fallback>` does not catch it, and a `2>/dev/null` on the call hides the
# only evidence. `fw doctor` stopped at line 31 of 113 with exit 1 and no message.
#
# Every test here was observed RED before the guard landed.

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PROJECT_ROOT
}

@test "fw_config with one arg does not kill a set -u caller" {
    run bash -c '
        set -euo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        v=$(fw_config INDEX_STALE_DAYS)
        echo "REACHED v=$v"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"REACHED"* ]]
}

@test "fw_config with one arg returns the registry default" {
    run bash -c '
        set -euo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        fw_config INDEX_STALE_DAYS
    '
    [ "$status" -eq 0 ]
    [ "$output" = "7" ]
}

@test "an explicit default still wins over the registry" {
    run bash -c '
        set -euo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        fw_config INDEX_STALE_DAYS 99
    '
    [ "$output" = "99" ]
}

@test "env var still wins over both" {
    run bash -c '
        set -euo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        FW_INDEX_STALE_DAYS=3 fw_config INDEX_STALE_DAYS
    '
    [ "$output" = "3" ]
}

@test "an unknown key with no default yields empty, not a crash" {
    # Absence must be reportable. A crash here would push callers straight back
    # to hardcoding the value at the call site, which is the habit the registry
    # exists to remove.
    run bash -c '
        set -euo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        v=$(fw_config NO_SUCH_KEY_T3013)
        echo "rc=$? v=[$v]"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"v=[]"* ]]
}

@test "fw_config_int with one arg does not kill a set -u caller" {
    run bash -c '
        set -euo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        v=$(fw_config_int INDEX_STALE_DAYS)
        echo "REACHED v=$v"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"REACHED v=7"* ]]
}

@test "the guard survives the caller redirecting stderr" {
    # This is the shape that hid the original bug: the unbound-variable message
    # went to /dev/null, so the only symptom was output stopping.
    run bash -c '
        set -euo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        v=$(fw_config INDEX_STALE_DAYS 2>/dev/null || echo FALLBACK)
        echo "REACHED v=$v"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"REACHED v=7"* ]]
}
