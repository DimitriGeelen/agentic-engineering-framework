#!/usr/bin/env bats
# T-4274 — a pushed pickup envelope must not share a basename with another
# project's envelope on the host-shared TermLink inbox.
#
# Origin: 0909 run (F-49). Each project numbers its own envelopes from P-001, and
# `termlink remote push` lands the file under its bare basename on the receiving
# host. Two projects' `P-001-learning.yaml` therefore overwrite each other there.
# The local envelope name is unchanged; only the copy that is pushed is qualified.
#
# T-3763: delivery is now a sidecar notice whose body is the envelope, so there
# is no shared-inbox basename at all. These tests keep the property that two
# projects' P-001 deliveries stay distinguishable at the receiver.

load ../test_helper

PICKUP_LIB="$FRAMEWORK_ROOT/lib/pickup.sh"

setup() {
    TMP_HOME=$(mktemp -d)
    RECV="$TMP_HOME/termlink-inbox"
    mkdir -p "$RECV"
    export RECV
    export NO_COLOR=1
}

teardown() {
    rm -rf "$TMP_HOME"
}

# Send one learning from project $1 to the shared inbox. Each project has its own
# PROJECT_ROOT, so the pickup dirs are re-derived by sourcing in a subshell.
# The pickup_sidecar_send stub stands in for the receiving host: it stores the
# delivered body in $RECV, one file per sending project.
_send_from() {
    local name="$1"
    (
        export PROJECT_ROOT="$TMP_HOME/$name"
        mkdir -p "$PROJECT_ROOT/.context/pickup/inbox"
        guard_project_root "$PROJECT_ROOT"
        # shellcheck source=lib/pickup.sh
        source "$PICKUP_LIB"
        pickup_sidecar_send() {
            while [ $# -gt 0 ]; do [ "$1" = --body ] && printf '%s' "$2" > "$RECV/$name"; shift; done
        }
        do_pickup_send --type learning --summary "from $name" --remote hub --session s >/dev/null
    )
}

@test "two projects' P-001 deliveries are distinguishable at the receiver" {
    _send_from alpha
    _send_from beta
    [ "$(find "$RECV" -maxdepth 1 -type f | wc -l)" -eq 2 ]
    grep -q "project: alpha" "$RECV/alpha"
    grep -q "project: beta" "$RECV/beta"
}

@test "each delivered body carries its pickup_id" {
    _send_from alpha
    _send_from beta
    [ "$(grep -l "pickup_id: P-001" "$RECV"/* | wc -l)" -eq 2 ]
}

@test "the local envelope keeps its name and is archived to sent/" {
    _send_from alpha
    [ -f "$TMP_HOME/alpha/.context/pickup/sent/P-001-learning.yaml" ]
}

@test "no staging directory is left behind in the pickup dir after a push" {
    _send_from alpha
    [ -z "$(find "$TMP_HOME/alpha/.context/pickup" -maxdepth 1 -name 'push.*' 2>/dev/null)" ]
}
