#!/usr/bin/env bats
# T-3059 — pickup_next_id reads the highest P-NNN and do_pickup_send writes the
# envelope afterwards. With nothing held between the two, concurrent sends read
# the same high-water mark and issue the same id (and, the filename being the
# id, aim at one inbox path). The fix holds one exclusive lock across allocate +
# write; this suite proves N concurrent sends give N distinct ids.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d -t fw-t3059-XXXXXX)
    mkdir -p "$TMP_PROJECT/.context/pickup/inbox"
    export PROJECT_ROOT="$TMP_PROJECT"
    export NO_COLOR=1
    # shellcheck source=lib/pickup.sh
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    [ -d "${TMP_PROJECT:-}" ] && rm -rf "$TMP_PROJECT"
}

@test "N concurrent sends yield N distinct ids and N envelopes" {
    local n=12 i
    for i in $(seq 1 "$n"); do
        do_pickup_send --type learning --summary "concurrent $i" --local >/dev/null 2>&1 &
    done
    wait

    local ids
    ids=$(grep -h '^pickup_id:' "$TMP_PROJECT/.context/pickup/undelivered/"*.yaml | sort)
    [ "$(printf '%s\n' "$ids" | wc -l)" -eq "$n" ]
    [ "$(printf '%s\n' "$ids" | sort -u | wc -l)" -eq "$n" ]
    [ "$(ls "$TMP_PROJECT/.context/pickup/undelivered/"*.yaml | wc -l)" -eq "$n" ]
}

@test "lock is released after a send, so a following send is not blocked" {
    run timeout 20 bash -c 'source "$1/lib/pickup.sh"; do_pickup_send --type learning --summary a --local && do_pickup_send --type learning --summary b --local' _ "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    [ "$(ls "$TMP_PROJECT/.context/pickup/undelivered/"*.yaml | wc -l)" -eq 2 ]
}
