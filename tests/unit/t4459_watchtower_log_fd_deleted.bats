#!/usr/bin/env bats
# T-4459 — the running Watchtower wrote stdout/stderr into a deleted watchtower.log.
# The file was tracked in git, so a `merge origin/master` (autostash cycle) replaced
# its inode while the server kept the old fd open; tracebacks became unreadable.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    LOG="$TEST_TEMP_DIR/watchtower.log"
}

teardown() {
    [ -n "${BG_PID:-}" ] && kill "$BG_PID" 2>/dev/null || true
    rm -rf "${TEST_TEMP_DIR:?}"
}

# Start a writer holding $LOG on fd 1/2 and wait until it really has it open —
# removing the file before the child's redirect runs would test nothing.
_start_writer() {
    sleep 60 > "$LOG" 2>&1 &
    BG_PID=$!
    local i
    for i in $(seq 50); do
        [ "$(readlink "/proc/$BG_PID/fd/1" 2>/dev/null)" = "$LOG" ] && return 0
        sleep 0.1
    done
    return 1
}

_check() {
    bash -c 'source "'"$FRAMEWORK_ROOT"'/lib/watchtower.sh" 2>/dev/null; watchtower_log_fd_deleted "$1"' _ "$1"
}

@test "fd check: a process whose log was deleted is reported, naming the fd" {
    _start_writer
    rm -f "$LOG"
    run _check "$BG_PID"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fd 1 -> $LOG (deleted)"* ]]
    [[ "$output" == *"fd 2 -> $LOG (deleted)"* ]]
}

@test "fd check: a process whose log is still on disk is not reported" {
    _start_writer
    run _check "$BG_PID"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "fd check: a dead or empty pid is 'cannot tell', not 'fine'" {
    run _check ""
    [ "$status" -eq 2 ]
    run _check 999999999
    [ "$status" -eq 2 ]
}

@test "repo: watchtower.log is untracked and ignored, so git cannot replace its inode" {
    cd "$FRAMEWORK_ROOT"
    run git ls-files --error-unmatch .context/working/watchtower.log
    [ "$status" -ne 0 ]
    git check-ignore -q .context/working/watchtower.log
}

@test "doctor: the Watchtower check wires the deleted-fd WARN" {
    grep -q 'watchtower_log_fd_deleted "\$_wt_pid"' "$FRAMEWORK_ROOT/bin/fw"
}
