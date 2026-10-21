#!/usr/bin/env bats
# T-4337 — two leftovers of the T-4306 / T-4332 classes.
#  (1) `bin/watchtower.sh status` read the port with an ss pipeline as a bare
#      assignment; under set -euo pipefail a missing ss (or no match) exited the
#      script silently after the "running" headline, with no PID/Log lines.
#  (2) lib/watchtower.sh (_watchtower_url Layer 1) and lib/watchtower-staleness.sh
#      (watchtower_process_start_epoch) used bare `kill -0`, which succeeds on a
#      ZOMBIE. Both now go through lib/pid-alive.sh:fw_pid_alive.
#
# Runs against a temp PROJECT_ROOT so it never reads this repo's own pid file.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    PROJ="$TEST_TEMP_DIR/project"
    W="$PROJ/.context/working"
    mkdir -p "$W" "$PROJ/.tasks/active" "$PROJ/.tasks/completed"
    LIVE=""
    ZPARENT=""
}

teardown() {
    [ -n "$LIVE" ] && kill -KILL "$LIVE" 2>/dev/null || true
    [ -n "$ZPARENT" ] && kill -KILL "$ZPARENT" 2>/dev/null || true
    rm -rf "${TEST_TEMP_DIR:?}"
}

# A real zombie: a parent forks a child that exits at once and never reaps it.
_zombie_pid() {
    python3 -c '
import os, time
pid = os.fork()
if pid == 0:
    os._exit(0)
print(pid, flush=True)
time.sleep(300)
' > "$TEST_TEMP_DIR/zpid" 3>&- &
    ZPARENT=$!
    local i
    for i in $(seq 1 50); do
        [ -s "$TEST_TEMP_DIR/zpid" ] && break
        sleep 0.1
    done
    ZOMBIE=$(tr -d '[:space:]' < "$TEST_TEMP_DIR/zpid")
    for i in $(seq 1 50); do
        [ "$(sed 's/.*) //' "/proc/$ZOMBIE/stat" 2>/dev/null | cut -d' ' -f1)" = "Z" ] && break
        sleep 0.1
    done
    # Precondition: kill -0 still succeeds — exactly what fooled the old checks.
    kill -0 "$ZOMBIE"
    [ "$(sed 's/.*) //' "/proc/$ZOMBIE/stat" | cut -d' ' -f1)" = "Z" ]
}

# A PATH holding every executable of the normal PATH except ss.
_path_without_ss() {
    local nb="$TEST_TEMP_DIR/noss" d f
    mkdir -p "$nb"
    IFS=: read -r -a _dirs <<< "$PATH"
    for d in "${_dirs[@]}"; do
        [ -d "$d" ] || continue
        for f in "$d"/*; do
            [ -x "$f" ] && [ ! -d "$f" ] || continue
            [ "$(basename "$f")" = "ss" ] && continue
            [ -e "$nb/$(basename "$f")" ] || ln -s "$f" "$nb/$(basename "$f")"
        done
    done
    echo "$nb"
}

@test "status: live pid with ss off PATH prints the full running block, exit 0" {
    sleep 300 3>&- &
    LIVE=$!
    echo "$LIVE" > "$W/watchtower.pid"
    nb=$(_path_without_ss)
    run env PATH="$nb" PROJECT_ROOT="$PROJ" "$FRAMEWORK_ROOT/bin/watchtower.sh" status 3>&-
    [ "$status" -eq 0 ]
    [[ "$output" == *"Watchtower is running"* ]]
    [[ "$output" == *"PID:    $LIVE"* ]]
    [[ "$output" == *"Log:"* ]]
}

@test "fw_pid_alive: live pid yes, zombie no, dead/empty no" {
    source "$FRAMEWORK_ROOT/lib/pid-alive.sh"
    fw_pid_alive "$$"
    _zombie_pid
    ! fw_pid_alive "$ZOMBIE" || false
    ! fw_pid_alive "" || false
}

@test "staleness: watchtower_process_start_epoch refuses a zombie pid" {
    source "$FRAMEWORK_ROOT/lib/watchtower-staleness.sh"
    watchtower_process_start_epoch "$$" >/dev/null
    _zombie_pid
    run watchtower_process_start_epoch "$ZOMBIE"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "_watchtower_url: a zombie pid in the triple is not trusted (Layer 1)" {
    _zombie_pid
    local zurl="http://127.0.0.1:1/t4337-zombie"
    echo "$ZOMBIE" > "$W/watchtower.pid"
    echo "1" > "$W/watchtower.port"
    echo "$zurl" > "$W/watchtower.url"
    run bash -c '
        unset WATCHTOWER_URL _FW_WATCHTOWER_LOADED _FW_PID_ALIVE_LOADED
        export PROJECT_ROOT="$1" FW_PORT=1
        source "$FRAMEWORK_ROOT/lib/watchtower.sh"
        # Identity "matches" only the zombie triple url, so the only way that
        # url comes back is Layer 1 trusting the zombie pid.
        eval "_watchtower_identity_matches() { [ \"\$1\" = \"$2\" ]; }"
        _watchtower_url
    ' _ "$PROJ" "$zurl"
    [[ "$output" != *"$zurl"* ]]
}
