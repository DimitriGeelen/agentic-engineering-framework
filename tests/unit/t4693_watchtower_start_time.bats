#!/usr/bin/env bats
# T-4693 — `fw watchtower current` flapped STALE for the NEW pid right after a
# `systemctl restart` (ring20 be.8: "pid predates 217 files", 25 s after the
# restart; the same pid read current a minute later).
#
# The start epoch was re-derived on every read as `date +%s - etimes`: two
# whole-second floors taken at two moments, so one pid read S on one call and
# S+1 on the next. `fw upgrade` writes all of web/ seconds before the restart,
# and the comparison was a strict `mtime > start` with no tolerance, so those
# files flipped between stale and current with the sub-second phase of the check.
#
# LIB_UNDER_TEST lets the same file be run against a pre-fix copy to prove the
# tests bite: LIB_UNDER_TEST=/path/to/old.sh bats <this file>

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="${LIB_UNDER_TEST:-$FRAMEWORK_ROOT/lib/watchtower-staleness.sh}"
    # shellcheck source=/dev/null
    . "$LIB"
    WEB="$BATS_TEST_TMPDIR/web"
    mkdir -p "$WEB"
    unset FW_WATCHTOWER_STALE_TOLERANCE
}

teardown() {
    [ -n "${LIVE_PID:-}" ] && kill "$LIVE_PID" 2>/dev/null
    return 0
}

_spawn() {
    sleep 60 &
    LIVE_PID=$!
}

@test "t4693: the start epoch of one pid is identical on every read" {
    # Six reads across ~3 s cross whole-second boundaries in both phases; the
    # pre-fix derivation returns two different values here.
    _spawn
    local first s i
    first=$(watchtower_process_start_epoch "$LIVE_PID")
    [ -n "$first" ]
    for i in 1 2 3 4 5 6; do
        sleep 0.5
        s=$(watchtower_process_start_epoch "$LIVE_PID")
        [ "$s" = "$first" ] || {
            echo "read $i: start epoch $s, first read $first — same pid, different start" >&2
            return 1
        }
    done
}

@test "t4693: on Linux the start epoch is /proc starttime + btime" {
    [ -r /proc/stat ] || skip "no /proc on this host"
    _spawn
    local btime hz ticks
    btime=$(awk '/^btime /{print $2}' /proc/stat)
    hz=$(getconf CLK_TCK)
    ticks=$(sed 's/.*) //' "/proc/$LIVE_PID/stat" | awk '{print $20}')
    run watchtower_process_start_epoch "$LIVE_PID"
    [ "$status" -eq 0 ]
    [ "$output" -eq $(( btime + ticks / hz )) ]
}

@test "t4693: files written in the second(s) around the start are not stale, on every read" {
    # The ring20 shape: fw upgrade rewrites web/ right before the restart.
    _spawn
    local s i
    s=$(watchtower_process_start_epoch "$LIVE_PID")
    touch -d "@$(( s - 1 ))" "$WEB/a.py"
    touch -d "@$s" "$WEB/b.html"
    touch -d "@$(( s + 1 ))" "$WEB/c.js"
    touch -d "@$(( s + 2 ))" "$WEB/d.css"
    for i in 1 2 3 4 5 6; do
        run watchtower_stale_sources "$LIVE_PID" "$WEB"
        [ "$status" -ne 0 ] || {
            echo "read $i flagged files within the start tolerance: $output" >&2
            return 1
        }
        sleep 0.5
    done
}

@test "t4693: a file modified clearly after the start is still stale" {
    # The non-vacuous leg: the tolerance must not hide a real post-start edit.
    _spawn
    local s
    s=$(watchtower_process_start_epoch "$LIVE_PID")
    touch -d "@$(( s - 100 ))" "$WEB/app.py"
    touch -d "@$(( s + 10 ))" "$WEB/inception.py"
    run watchtower_stale_sources "$LIVE_PID" "$WEB"
    [ "$status" -eq 0 ]
    [[ "$output" == *"inception.py"* ]]
    ! [[ "$output" == *"app.py"* ]] || false
}

@test "t4693: FW_WATCHTOWER_STALE_TOLERANCE=0 restores the strict comparison; junk falls back to 2" {
    _spawn
    local s
    s=$(watchtower_process_start_epoch "$LIVE_PID")
    touch -d "@$(( s + 1 ))" "$WEB/c.js"
    FW_WATCHTOWER_STALE_TOLERANCE=0 run watchtower_stale_sources "$LIVE_PID" "$WEB"
    [ "$status" -eq 0 ]
    FW_WATCHTOWER_STALE_TOLERANCE=abc run watchtower_stale_sources "$LIVE_PID" "$WEB"
    [ "$status" -ne 0 ]
}
