#!/usr/bin/env bats
# T-2802 — `fw watchtower url` must not answer with a guess.
#
# do_url used to end in `echo "http://localhost:$(fw_config PORT 3000)"` — a
# well-known-port guess emitted in exactly the shape of a verified answer.
# lib/watchtower.sh's _watchtower_url has refused to do that since T-1803
# ("never return a URL to a service we didn't positively identify"); this
# accessor — the one CLAUDE.md tells agents to put inside ## Verification —
# kept doing it.
#
# Why it matters more than it sounds: consumer projects run the same Flask app,
# so a foreign Watchtower on the guessed port answers 200 for almost any path.
# A verification line built on the guess passes while asserting nothing. That is
# the T-2732/T-2734 false-green class, which reached 371 lines before anyone
# noticed — a red line gets looked at, a green one that asserts nothing never
# prompts anybody.
#
# Observed live 2026-08-04 in /opt/2345-test-install (OBS-158). On the origin
# host the guessed :3000 was /opt/832-Workflow-designer's Watchtower.

bats_require_minimum_version 1.5.0

WT() { echo "$BATS_TEST_DIRNAME/../../bin/watchtower.sh"; }

# A port nothing is expected to hold. Fixed rather than random so a failure is
# reproducible; the tests that need a listener bind their own and report it.
DEAD_PORT=39117

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working"
    printf 'project_name: t2802\nversion: 1.0\n' > "$PROJ/.framework.yaml"
    FAKE_PID=""
}

teardown() {
    [ -n "${FAKE_PID:-}" ] && kill "$FAKE_PID" 2>/dev/null
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Start a server that answers /api/_identity as a DIFFERENT project's Watchtower.
# Echoes the port it bound. Binding :0 and reporting back avoids racing whatever
# else is on this host.
_start_foreign_watchtower() {
    local out="$TEST_TEMP_DIR/foreign.port"
    # A file, not a heredoc: a heredoc feeding a backgrounded process wedges
    # bats (L-408).
    #
    # `3>&-` is load-bearing. bats reports through fd 3, and a background process
    # that inherits it keeps the pipe open after the test ends — bats then waits
    # for a writer that never exits and the whole run hangs with no output. Cost
    # me a `timeout 240` to see, because a hang looks like a slow test.
    python3 "$BATS_TEST_DIRNAME/../fixtures/foreign_watchtower.py" "$out" \
        >/dev/null 2>&1 3>&- </dev/null &
    FAKE_PID=$!
    local i
    for i in $(seq 1 50); do
        [ -s "$out" ] && { cat "$out"; return 0; }
        sleep 0.1
    done
    return 1
}

@test "refuses when nothing is listening, instead of guessing a URL" {
    run env PROJECT_ROOT="$PROJ" FW_PORT="$DEAD_PORT" "$(WT)" url
    [ "$status" -ne 0 ]
    # The old behaviour, spelled out so a regression is unmistakable.
    if echo "$output" | grep -q "http://localhost:$DEAD_PORT"; then false; fi
    echo "$output" | grep -q 'Nothing is listening'
    echo "$output" | grep -q 'fw serve'
}

@test "refuses and says FOREIGN when someone else holds the port" {
    local fport
    fport="$(_start_foreign_watchtower)"
    [ -n "$fport" ]

    run env PROJECT_ROOT="$PROJ" FW_PORT="$fport" "$(WT)" url
    [ "$status" -ne 0 ]
    if echo "$output" | grep -q "http://localhost:$fport"; then false; fi
    # Must not read as "not running" — the fix is different (pick another port),
    # and curling it is the actual hazard.
    echo "$output" | grep -q 'not this'
    echo "$output" | grep -q '/opt/some-other-project'
}

@test "the refusal names which project it was asked about" {
    # On a multi-project host that is half the answer. PROJECT_ROOT is always
    # set for this entry point (lib/paths.sh:39-46 falls back to FRAMEWORK_ROOT),
    # so there is no "no project" case to test here — an earlier draft of this
    # task assumed one and shipped an unreachable guard for it.
    run env PROJECT_ROOT="$PROJ" FW_PORT="$DEAD_PORT" "$(WT)" url
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "Project: $PROJ"
}

@test "a triple-file URL is still returned — it is ours by construction" {
    # Non-vacuity: proves the refusals above are about unverifiable answers, not
    # a function that now refuses everything.
    echo "http://10.1.2.3:4567" > "$PROJ/.context/working/watchtower.url"
    run env PROJECT_ROOT="$PROJ" FW_PORT="$DEAD_PORT" "$(WT)" url
    [ "$status" -eq 0 ]
    [ "$output" = "http://10.1.2.3:4567" ]
}

@test "WATCHTOWER_URL override wins — a caller who states the answer is not guessing" {
    run env PROJECT_ROOT="$PROJ" WATCHTOWER_URL="http://stated:1234" "$(WT)" url
    [ "$status" -eq 0 ]
    [ "$output" = "http://stated:1234" ]
}

@test "fw watchtower port still answers — a port is configuration, not a claim" {
    # The split this task rests on: `port` says what we would use, `url` says
    # where a server IS. Only the second needs evidence.
    run env PROJECT_ROOT="$PROJ" FW_PORT="$DEAD_PORT" "$(WT)" port
    [ "$status" -eq 0 ]
    [ "$output" = "$DEAD_PORT" ]
}
