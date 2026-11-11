#!/usr/bin/env bats
# T-5078 — fw_pid_alive ran `kill -0` (true on a zombie) and then read the
# process state. When the parent reaped the zombie in between, the read came
# back empty, and empty is not "Z", so a process that no longer existed read as
# ALIVE. `watchtower stop` then printed "Failed to stop" for a stop that worked.
#
# The race is simulated: a pid that does not exist (so /proc/PID/stat is not
# readable and the ps branch runs), a `kill` stub that answers "exists" once and
# "gone" after that, and a `ps` stub that prints nothing — exactly the order of
# events in the trace.

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }

@test "T-5078: a process reaped between kill -0 and the state read is not alive" {
    run bash -c '
        source "$1/lib/pid-alive.sh"
        n=0
        kill() { n=$((n + 1)); [ "$n" -eq 1 ]; }   # first kill -0: exists; then gone
        ps() { :; }                                  # state read finds nothing
        pid=999999999
        if fw_pid_alive "$pid"; then echo ALIVE; else echo GONE; fi
    ' _ "$(ROOT)"
    [ "$status" -eq 0 ]
    [ "$output" = "GONE" ]
}

@test "T-5078 control: a live process is still alive" {
    sleep 30 &
    local pid=$!
    run bash -c 'source "$1/lib/pid-alive.sh"; fw_pid_alive "$2" && echo ALIVE || echo GONE' _ "$(ROOT)" "$pid"
    kill "$pid" 2>/dev/null || true
    [ "$output" = "ALIVE" ]
}

@test "T-5078 control: a zombie is still not alive" {
    # A child that exits while its parent sleeps stays a zombie until reaped.
    run bash -c '
        source "$1/lib/pid-alive.sh"
        ( exit 0 ) & z=$!
        sleep 0.5
        fw_pid_alive "$z" && echo ALIVE || echo GONE
    ' _ "$(ROOT)"
    [ "$output" = "GONE" ]
}
