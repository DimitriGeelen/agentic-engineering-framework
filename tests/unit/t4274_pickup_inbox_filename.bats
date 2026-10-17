#!/usr/bin/env bats
# T-4274 — a pushed pickup envelope must not share a basename with another
# project's envelope on the host-shared TermLink inbox.
#
# Origin: 0909 run (F-49). Each project numbers its own envelopes from P-001, and
# `termlink remote push` lands the file under its bare basename on the receiving
# host. Two projects' `P-001-learning.yaml` therefore overwrite each other there.
# The local envelope name is unchanged; only the copy that is pushed is qualified.

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
# The termlink stub stands in for the receiving host: it copies the pushed file
# into $RECV under the basename it was pushed with.
_send_from() {
    local name="$1"
    (
        export PROJECT_ROOT="$TMP_HOME/$name"
        mkdir -p "$PROJECT_ROOT/.context/pickup/inbox"
        guard_project_root "$PROJECT_ROOT"
        # shellcheck source=lib/pickup.sh
        source "$PICKUP_LIB"
        termlink() { cp "$5" "$RECV/$(basename "$5")"; return 0; }
        do_pickup_send --type learning --summary "from $name" --remote hub --session s >/dev/null
    )
}

@test "two projects' P-001 pushes land under different basenames on the shared inbox" {
    _send_from alpha
    _send_from beta
    [ "$(find "$RECV" -maxdepth 1 -type f | wc -l)" -eq 2 ]
}

@test "pushed basenames keep the P-NNN- prefix so P-*.yaml readers still match" {
    _send_from alpha
    _send_from beta
    [ "$(ls "$RECV"/P-001-*.yaml | wc -l)" -eq 2 ]
}

@test "the local envelope keeps its name and is archived to sent/" {
    _send_from alpha
    [ -f "$TMP_HOME/alpha/.context/pickup/sent/P-001-learning.yaml" ]
}

@test "no staging directory is left behind in the pickup dir after a push" {
    _send_from alpha
    [ -z "$(find "$TMP_HOME/alpha/.context/pickup" -maxdepth 1 -name 'push.*' 2>/dev/null)" ]
}
