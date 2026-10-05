#!/usr/bin/env bats
# T-3662 — every unconfigured project resolved :3000, so a second project on the
# same host refused to start (P-01 WSL F-28). Unconfigured projects now allocate
# the first port from PORT_SCAN_BASE that is free or already theirs, skipping
# foreign holders, and record it; `start` reuses a running server only after
# /api/_identity says it is ours.
#
# Every server here is started against a temp project on a scan base chosen in
# a free high range, ufw is stubbed, and teardown kills only pids this test
# started or that its own temp projects' pid files name.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    mkdir -p "$TEST_TEMP_DIR/bin"
    printf '#!/bin/sh\necho "Status: inactive"\n' > "$TEST_TEMP_DIR/bin/ufw"
    chmod +x "$TEST_TEMP_DIR/bin/ufw"
    for p in a b; do
        mkdir -p "$TEST_TEMP_DIR/$p/.context/working" "$TEST_TEMP_DIR/$p/.tasks/active" "$TEST_TEMP_DIR/$p/.tasks/completed"
        printf 'project_name: %s\n' "$p" > "$TEST_TEMP_DIR/$p/.framework.yaml"
    done
    # A base whose first 5 ports are all free right now.
    BASE=$(python3 - <<'PY'
import random, socket
for _ in range(200):
    b = random.randint(40000, 59000)
    ok = True
    for p in range(b, b + 5):
        s = socket.socket()
        try:
            s.bind(("0.0.0.0", p))
        except OSError:
            ok = False
        finally:
            s.close()
    if ok:
        print(b)
        break
PY
)
    [ -n "$BASE" ]
    EXTRA_PIDS=""
}

teardown() {
    local f q
    for f in "$TEST_TEMP_DIR"/a/.context/working/watchtower.pid "$TEST_TEMP_DIR"/b/.context/working/watchtower.pid; do
        q=$(cat "$f" 2>/dev/null || true)
        [ -n "$q" ] || continue
        pkill -KILL -P "$q" 2>/dev/null || true
        kill -KILL "$q" 2>/dev/null || true
    done
    for q in $EXTRA_PIDS; do kill -KILL "$q" 2>/dev/null || true; done
    rm -rf "${TEST_TEMP_DIR:?}"
}

# _wt PROJECT ARGS... — run watchtower.sh for a temp project, no FW_PORT.
_wt() {
    local proj="$1"; shift
    run env -u FW_PORT PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$TEST_TEMP_DIR/$proj" \
        FW_PORT_SCAN_BASE="$BASE" "$FRAMEWORK_ROOT/bin/watchtower.sh" "$@" 3>&-
}

_port_of() { cat "$TEST_TEMP_DIR/$1/.context/working/watchtower.port"; }

_identity_root() {
    curl -sf --max-time 2 "http://localhost:$1/api/_identity" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["project_root"])'
}

# A foreign listener: answers HTTP, but not /api/_identity as a Watchtower.
_foreign_on() {
    python3 -m http.server "$1" --bind 0.0.0.0 --directory "$TEST_TEMP_DIR" >/dev/null 2>&1 3>&- &
    EXTRA_PIDS="$EXTRA_PIDS $!"
    local i=0
    while [ "$i" -lt 20 ] && ! ss -tln | grep -q ":$1 "; do sleep 0.25; i=$((i + 1)); done
}

@test "two unconfigured projects get different ports, each serving itself, each recorded" {
    _wt a start
    [ "$status" -eq 0 ]
    _wt b start
    [ "$status" -eq 0 ]
    pa=$(_port_of a); pb=$(_port_of b)
    [ "$pa" != "$pb" ]
    [ "$pa" -ge "$BASE" ] && [ "$pa" -lt $((BASE + 100)) ]
    [ "$pb" -ge "$BASE" ] && [ "$pb" -lt $((BASE + 100)) ]
    [ "$(_identity_root "$pa")" = "$TEST_TEMP_DIR/a" ]
    [ "$(_identity_root "$pb")" = "$TEST_TEMP_DIR/b" ]
    grep -q "^PORT: $pa\$" "$TEST_TEMP_DIR/a/.framework.yaml"
    grep -q "^PORT: $pb\$" "$TEST_TEMP_DIR/b/.framework.yaml"
}

@test "allocation skips a foreign holder of the base port and leaves it alive" {
    _foreign_on "$BASE"
    foreign_pid=${EXTRA_PIDS##* }
    _wt a start
    [ "$status" -eq 0 ]
    [ "$(_port_of a)" != "$BASE" ]
    kill -0 "$foreign_pid"
}

@test "a configured PORT held by a foreign service: start moves on LOUDLY, the holder survives, PORT is not rewritten" {
    # T-3876 changed 'refuse' to 'start elsewhere and say so' (operator ask via
    # 055: "if that fails, find a new port" — a refusal leaves Watchtower down
    # after every reboot a neighbour won the race for). What T-3662/T-1803
    # protect is unchanged: the foreign holder is never signalled.
    printf 'PORT: %s\n' "$BASE" >> "$TEST_TEMP_DIR/a/.framework.yaml"
    _foreign_on "$BASE"
    foreign_pid=${EXTRA_PIDS##* }
    _wt a start
    [ "$status" -eq 0 ]
    [ "$(_port_of a)" != "$BASE" ]
    [[ "$output" == *"PORT ${BASE} (configured) is held by another service"* ]]
    kill -0 "$foreign_pid"
    grep -q "^PORT: ${BASE}\$" "$TEST_TEMP_DIR/a/.framework.yaml"
}

@test "start on an already-running, identity-verified server reuses it (exit 0)" {
    _wt a start
    [ "$status" -eq 0 ]
    pid1=$(cat "$TEST_TEMP_DIR/a/.context/working/watchtower.pid")
    pa=$(_port_of a)
    _wt a start
    [ "$status" -eq 0 ]
    [[ "$output" == *"already running"* ]]
    [[ "$output" == *":$pa"* ]]
    [ "$(cat "$TEST_TEMP_DIR/a/.context/working/watchtower.pid")" = "$pid1" ]
}

@test "a live pid whose port does not identify as ours is not reused" {
    sleep 300 3>&- &
    EXTRA_PIDS="$EXTRA_PIDS $!"
    echo "$!" > "$TEST_TEMP_DIR/a/.context/working/watchtower.pid"
    _foreign_on "$BASE"
    echo "$BASE" > "$TEST_TEMP_DIR/a/.context/working/watchtower.port"
    _wt a start
    [ "$status" -ne 0 ]
    [[ "$output" != *"identity verified"* ]]
}
