#!/usr/bin/env bats
# T-3379 — the "Watchtower not running" placeholder must never name a port that
# something else already holds.
#
# Observed 2026-09-17, after a host reboot killed this project's Watchtower.
# `fw task review T-2171` correctly reported "No Watchtower reachable" and then
# printed `http://localhost:3000/review/T-2171`. The link came from
# `_watchtower_base_or_placeholder`, which built it from the bare configured
# port. On that host :3000 was held by a DIFFERENT project's Watchtower,
# running the same Flask app, so the human-review handoff pointed at a foreign
# server (the T-1376/T-2732 wrong-server class). Low task IDs collide across
# projects, so such a link can render a real-looking page for the wrong task.
#
# Meanwhile the triple file still held :3002. That is where this project last
# ran, and where a bare `fw watchtower restart` rebinds (T-2598). It was the
# right answer, and it was ignored.
#
# The T-2922 contract is kept and pinned here too: the placeholder path still
# answers non-empty on stdout and exits 2, so emit_review never aborts before
# its `.reviewed-<id>` marker write.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT_ROOT/.context/working"
    printf 'project_name: t3379\nversion: 1.0\n' > "$PROJECT_ROOT/.framework.yaml"
    unset WATCHTOWER_URL
    unset _FW_WATCHTOWER_LOADED _FW_CONFIG_LOADED _FW_PATHS_LOADED
    FOREIGN_PID=""
}

teardown() {
    [ -n "${FOREIGN_PID:-}" ] && kill "$FOREIGN_PID" 2>/dev/null
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Start ANOTHER project's Watchtower on an ephemeral port and echo that port.
# The shared fixture binds :0, which avoids racing whatever else is on the host.
# `3>&-` keeps the background process off bats' reporting fd (see
# watchtower_url_no_guess.bats for the hang that taught this).
_start_foreign_watchtower() {
    local out="$TEST_TEMP_DIR/foreign.port"
    python3 "$BATS_TEST_DIRNAME/../fixtures/foreign_watchtower.py" "$out" \
        >/dev/null 2>&1 3>&- </dev/null &
    FOREIGN_PID=$!
    local i
    for i in $(seq 1 50); do
        [ -s "$out" ] && { cat "$out"; return 0; }
        sleep 0.1
    done
    return 1
}

# A port nothing is listening on right now: bind :0, read it, release it.
_free_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

# Run the function under test in a clean subshell. Output is "<exit>|<stdout>".
# stderr is dropped: `run` merges it into $output, and the resolver's
# "No Watchtower reachable" notice would then sit in front of the exit code.
_placeholder() {
    bash -c 'source "$1/lib/watchtower.sh"; out=$(_watchtower_base_or_placeholder T-3379 2>/dev/null); echo "$?|$out"' _ "$FRAMEWORK_ROOT"
}

@test "foreign Watchtower on the configured port, no triple file: that port is NOT named" {
    local fport
    fport=$(_start_foreign_watchtower)
    [ -n "$fport" ]
    export FW_PORT="$fport"

    run _placeholder
    [ "$status" -eq 0 ]
    [ "${output%%|*}" = "2" ]
    local url="${output#*|}"
    [ -n "$url" ]
    # This exact URL is the incident.
    [[ "$url" != *":${fport}"* ]]
}

@test "stale triple-file port wins over a foreign-held configured port" {
    local fport tport
    fport=$(_start_foreign_watchtower)
    [ -n "$fport" ]
    tport=$(_free_port)
    export FW_PORT="$fport"
    printf '%s\n' "$tport" > "$PROJECT_ROOT/.context/working/watchtower.port"

    run _placeholder
    [ "${output%%|*}" = "2" ]
    [ "${output#*|}" = "http://localhost:${tport}" ]
}

@test "triple-file port held by a foreign service falls back to a free configured port" {
    local fport cport
    fport=$(_start_foreign_watchtower)
    [ -n "$fport" ]
    cport=$(_free_port)
    export FW_PORT="$cport"
    printf '%s\n' "$fport" > "$PROJECT_ROOT/.context/working/watchtower.port"

    run _placeholder
    [ "${output%%|*}" = "2" ]
    [ "${output#*|}" = "http://localhost:${cport}" ]
}

@test "every candidate foreign-held: a non-resolvable .invalid placeholder, still non-empty, still exit 2" {
    local fport
    fport=$(_start_foreign_watchtower)
    [ -n "$fport" ]
    export FW_PORT="$fport"
    printf '%s\n' "$fport" > "$PROJECT_ROOT/.context/working/watchtower.port"

    run _placeholder
    [ "${output%%|*}" = "2" ]
    local url="${output#*|}"
    [ -n "$url" ]
    [[ "$url" != *":${fport}"* ]]
    # RFC 2606: .invalid can never resolve, so a click can't reach anyone's server.
    [[ "$url" == *".invalid"* ]]
}

@test "T-2922 preserved: nothing listening, no triple file -> configured port, exit 2" {
    local cport
    cport=$(_free_port)
    export FW_PORT="$cport"

    run _placeholder
    [ "${output%%|*}" = "2" ]
    [ "${output#*|}" = "http://localhost:${cport}" ]
}
