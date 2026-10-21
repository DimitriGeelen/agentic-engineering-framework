#!/usr/bin/env bats
# T-4175 — `fw pickup send` with no target must fail, local-only must be an
# explicit --local, and an outgoing envelope must never land in the sender's
# own inbound inbox.
#
# Origin: dimitri-mint-dev P-013 (their T-113). Five bug reports sent with no
# --remote each exited 0 and were written to .context/pickup/inbox/, where
# `fw pickup process` would file the sender's outgoing reports as inbound work.

load ../test_helper

setup() {
    TMP_PROJECT=$(mktemp -d)
    guard_project_root "$TMP_PROJECT"
    mkdir -p "$TMP_PROJECT/.context/pickup/inbox"
    export PROJECT_ROOT="$TMP_PROJECT"
    export NO_COLOR=1
    D="$TMP_PROJECT/.context/pickup"
    # shellcheck source=lib/pickup.sh
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

_envelope_count() {
    find "$D" -name 'P-*.yaml' | wc -l
}

@test "send with no target exits non-zero, names both options, writes nothing" {
    run do_pickup_send --type bug-report --summary "no target"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--remote"* ]]
    [[ "$output" == *"--local"* ]]
    [ "$(_envelope_count)" -eq 0 ]
}

@test "--session alone is still no target" {
    run do_pickup_send --type bug-report --summary "x" --session peer
    [ "$status" -ne 0 ]
    [ "$(_envelope_count)" -eq 0 ]
}

@test "--local saves to undelivered/, not the inbox, and says NOT delivered" {
    run do_pickup_send --type bug-report --summary "local only" --local
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT delivered"* ]]
    [ -f "$D/undelivered/P-001-bug-report.yaml" ]
    [ ! -e "$D/inbox/P-001-bug-report.yaml" ]
}

@test "--local envelope id is spent: the next send gets the next id" {
    do_pickup_send --type learning --summary a --local >/dev/null 2>&1
    do_pickup_send --type learning --summary b --local >/dev/null 2>&1
    [ -f "$D/undelivered/P-001-learning.yaml" ]
    [ -f "$D/undelivered/P-002-learning.yaml" ]
}

@test "--local with --remote is refused" {
    run do_pickup_send --type learning --summary x --local --remote hub --session s
    [ "$status" -ne 0 ]
    [ "$(_envelope_count)" -eq 0 ]
}

@test "the envelope is not in the inbox even while the remote push runs" {
    pickup_sidecar_send() {
        find "$D/inbox" -name 'P-*.yaml' > "$TMP_PROJECT/inbox-during-push"
        return 0
    }
    run do_pickup_send --type learning --summary x --remote hub --session s
    [ "$status" -eq 0 ]
    [ ! -s "$TMP_PROJECT/inbox-during-push" ]
    [ -f "$D/sent/P-001-learning.yaml" ]
}
