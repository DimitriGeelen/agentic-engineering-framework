#!/usr/bin/env bats
# T-3763 — `fw pickup send --remote` must deliver through the one channel
# (fw sidecar send, T-3631 GO / T-3758), not the deprecated `termlink remote
# push`, and a failed delivery must not leave the envelope in the sender's own
# inbox, where `fw pickup process` reads it as incoming.
#
# Origin: 055 @135. The hub allowlist refuses remote push's
# `mkdir -p /tmp/termlink-inbox`: nothing was delivered and the envelope stayed
# in the sender's inbox.

load ../test_helper

PICKUP_LIB="$FRAMEWORK_ROOT/lib/pickup.sh"

setup() {
    TMP_PROJECT=$(mktemp -d)
    guard_project_root "$TMP_PROJECT"
    mkdir -p "$TMP_PROJECT/.context/pickup/inbox"
    export PROJECT_ROOT="$TMP_PROJECT"
    export NO_COLOR=1
    D="$TMP_PROJECT/.context/pickup"
    CALLS="$TMP_PROJECT/calls"
    export CALLS
    # Any termlink call is the deprecated path — record it.
    termlink() { echo "termlink $*" >> "$CALLS"; return 0; }
    export -f termlink
    # shellcheck source=lib/pickup.sh
    source "$PICKUP_LIB"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

@test "send --remote never calls termlink remote push" {
    pickup_sidecar_send() { return 0; }
    run do_pickup_send --type learning --summary "x" --remote hub --session peer
    [ "$status" -eq 0 ]
    ! grep -q "remote push" "$CALLS" 2>/dev/null || false
}

@test "send --remote delivers via fw sidecar send --to SESSION --hub REMOTE --notice with the envelope" {
    pickup_sidecar_send() { printf '%s\n' "$@" > "$CALLS.sidecar"; return 0; }
    run do_pickup_send --type learning --summary "via sidecar" --remote hubprof --session peer-7
    [ "$status" -eq 0 ]
    grep -qx -- "--to" "$CALLS.sidecar"
    grep -qx -- "peer-7" "$CALLS.sidecar"
    grep -qx -- "hubprof" "$CALLS.sidecar"
    grep -qx -- "--notice" "$CALLS.sidecar"
    grep -q "pickup_id: P-001" "$CALLS.sidecar"
    grep -q "summary: via sidecar" "$CALLS.sidecar"
    grep -q "project: $(basename "$TMP_PROJECT")" "$CALLS.sidecar"
    [ -f "$D/sent/P-001-learning.yaml" ]
    [ ! -e "$D/inbox/P-001-learning.yaml" ]
}

@test "a failed delivery exits non-zero and takes the envelope out of the inbox" {
    pickup_sidecar_send() { echo "REFUSED"; return 2; }
    run do_pickup_send --type learning --summary "fails" --remote hub --session peer
    [ "$status" -ne 0 ]
    [[ "$output" == *"NOT delivered"* ]]
    [ ! -e "$D/inbox/P-001-learning.yaml" ]
    [ -f "$D/undelivered/P-001-learning.yaml" ]
}

@test "an id held only in undelivered/ is not reissued" {
    mkdir -p "$D/undelivered"
    printf 'pickup_id: "P-004"\n' > "$D/undelivered/P-004-learning.yaml"
    [ "$(pickup_next_id)" = "P-005" ]
}
