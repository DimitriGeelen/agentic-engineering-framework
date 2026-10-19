#!/usr/bin/env bats
# T-4378 — the shared hermetic fixture (tests/unit/helpers/hermetic.bash) does what
# it says: env stripped, private TMPDIR and project, and every tripwire fires on a
# deliberate leak. The leaks below are aimed at fakes, never at the real checkout.

load helpers/hermetic

setup() {
    # What a worker shell or the nightly cron hands a test.
    export PROJECT_ROOT=/nonexistent/inherited FRAMEWORK_ROOT=/nonexistent/fw
    export FW_T4378_PROBE=1 CLAUDECODE=1 CLAUDE_T4378_PROBE=1
    hermetic_setup --project
}

teardown() {
    hermetic_teardown
}

@test "inherited PROJECT_ROOT, FRAMEWORK_ROOT, CLAUDE* and FW_* are stripped" {
    [ -z "${PROJECT_ROOT+x}" ]
    [ -z "${FRAMEWORK_ROOT+x}" ]
    [ -z "${FW_T4378_PROBE+x}" ]
    [ -z "${CLAUDECODE+x}" ]
    [ -z "${CLAUDE_T4378_PROBE+x}" ]
    run env
    [[ "$output" != *"/nonexistent/"* ]]
}

@test "TMPDIR, cwd and the project are private and the project has fw's markers" {
    [ "$TMPDIR" = "$HERMETIC_ROOT/tmp" ]
    [[ "$(mktemp)" == "$HERMETIC_ROOT/tmp/"* ]]
    [ "$PWD" = "$HERMETIC_PROJECT" ]
    [ -d "$HERMETIC_PROJECT/.tasks/active" ]
    [ -d "$HERMETIC_PROJECT/.context/working" ]
    [ -d "$HERMETIC_HOME" ]
}

@test "a fw call routes to the temp project and the decoy port, and trips nothing" {
    hermetic_run "$HERMETIC_REPO/bin/fw" watchtower port
    [ "$status" -eq 0 ]
    [[ "$output" == *"$FW_PORT"* ]]
    run hermetic_tripwires
    [ "$status" -eq 0 ]
}

@test "tripwire: a termlink non-probe call fails the test" {
    termlink send nobody hello >/dev/null 2>&1 || true
    run hermetic_tripwires
    [ "$status" -ne 0 ]
    [[ "$output" == *"termlink non-probe call"* ]]
    rm -f "$TERMLINK_TRIPWIRE_LOG"
}

@test "tripwire: a connection to Watchtower fails the test" {
    python3 -c 'import socket, sys; socket.create_connection(("127.0.0.1", int(sys.argv[1])), 2).close()' "$FW_PORT"
    local i
    for i in $(seq 1 100); do
        [ -s "$HERMETIC_ROOT/.decoy.log" ] && break
        sleep 0.02
    done
    run hermetic_tripwires
    [ "$status" -ne 0 ]
    [[ "$output" == *"connected to Watchtower"* ]]
    rm -f "$HERMETIC_ROOT/.decoy.log"
}

@test "tripwire: the live sidecar's stop marker appearing fails the test" {
    HERMETIC_SIDECAR_STOPPED="$HERMETIC_ROOT/fake-sidecar-stopped"
    touch "$HERMETIC_SIDECAR_STOPPED"
    run hermetic_tripwires
    [ "$status" -ne 0 ]
    [[ "$output" == *"live sidecar was explicitly stopped"* ]]
    rm -f "$HERMETIC_SIDECAR_STOPPED"
}

@test "tripwire: a new entry in the checkout or its .context fails the test" {
    HERMETIC_REPO="$HERMETIC_ROOT/fake-repo"
    mkdir -p "$HERMETIC_REPO/.context"
    _hermetic_snapshot > "$HERMETIC_ROOT/.live-before"
    mkdir "$HERMETIC_REPO/.context/leaked"
    run hermetic_tripwires
    [ "$status" -ne 0 ]
    [[ "$output" == *".context/leaked"* ]]
    rmdir "$HERMETIC_REPO/.context/leaked"
}

@test "hermetic_allow_watchtower silences the Watchtower tripwire only with a reason" {
    run hermetic_allow_watchtower ""
    [ "$status" -ne 0 ]
    python3 -c 'import socket, sys; socket.create_connection(("127.0.0.1", int(sys.argv[1])), 2).close()' "$FW_PORT"
    local i
    for i in $(seq 1 100); do
        [ -s "$HERMETIC_ROOT/.decoy.log" ] && break
        sleep 0.02
    done
    hermetic_allow_watchtower "self-test: probing on purpose"
    run hermetic_tripwires
    [ "$status" -eq 0 ]
}
