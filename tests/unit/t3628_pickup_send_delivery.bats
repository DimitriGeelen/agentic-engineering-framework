#!/usr/bin/env bats
# T-3628 — `fw pickup send` must say when nothing was delivered, and a sent
# envelope's id must stay counted.
#
# Origin: 055 (framework:pickup 257). `send` without --remote wrote to the
# SENDER's own inbox and printed "Created"; a failed `termlink remote push` was
# indistinguishable from a successful one; and an outgoing envelope, once cleared
# from the sender's inbox, dropped out of pickup_next_id, so P-001 was reissued.

load ../test_helper

PICKUP_LIB="$FRAMEWORK_ROOT/lib/pickup.sh"

setup() {
    TMP_PROJECT=$(mktemp -d)
    guard_project_root "$TMP_PROJECT"
    mkdir -p "$TMP_PROJECT/.context/pickup/inbox"
    export PROJECT_ROOT="$TMP_PROJECT"
    export NO_COLOR=1
    D="$TMP_PROJECT/.context/pickup"
    # shellcheck source=lib/pickup.sh
    source "$PICKUP_LIB"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

@test "send without --remote says plainly that nothing was delivered" {
    run do_pickup_send --type learning --summary "local only"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT delivered"* ]]
    [ -f "$D/inbox/P-001-learning.yaml" ]
}

@test "a failed remote push says NOT delivered and exits non-zero" {
    termlink() { echo "hub refused"; return 7; }
    export -f termlink
    run do_pickup_send --type learning --summary "push fails" --remote hub --session s
    [ "$status" -ne 0 ]
    [[ "$output" == *"NOT delivered"* ]]
    # Undelivered: it stays where the operator can find and resend it.
    [ -f "$D/inbox/P-001-learning.yaml" ]
}

@test "a successful remote push archives the envelope to sent/, out of the sender's inbox" {
    termlink() { return 0; }
    export -f termlink
    run do_pickup_send --type learning --summary "delivered" --remote hub --session s
    [ "$status" -eq 0 ]
    [[ "$output" != *"NOT delivered"* ]]
    [ -f "$D/sent/P-001-learning.yaml" ]
    [ ! -e "$D/inbox/P-001-learning.yaml" ]
}

@test "an id held only in sent/ is not reissued" {
    mkdir -p "$D/sent"
    printf 'pickup_id: "P-004"\n' > "$D/sent/P-004-learning.yaml"
    [ "$(pickup_next_id)" = "P-005" ]
}

@test "mutation: dropping sent/ from the allocator reissues the id" {
    mkdir -p "$D/sent"
    printf 'pickup_id: "P-004"\n' > "$D/sent/P-004-learning.yaml"
    local m="$TMP_PROJECT/pickup-mutant.sh"
    sed 's#for dir in "\$PICKUP_SENT" #for dir in #' "$PICKUP_LIB" > "$m"
    if cmp -s "$m" "$PICKUP_LIB"; then
        echo "mutation did not land"; false
    fi
    # shellcheck disable=SC1090
    source "$m"
    [ "$(pickup_next_id)" = "P-001" ]
}
