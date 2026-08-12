#!/usr/bin/env bats
# T-2938 — a running Watchtower can serve code that no longer exists on disk.
#
# T-2925's GO decision was recorded through Watchtower and refused at the commit
# boundary by the G-052 dup-task-ID scan — the failure T-2864 had already fixed
# in web/blueprints/inception.py. Both were true: fix on disk (Aug 8 09:38),
# defect in the process (started Aug 6 23:44, debug=False, no reloader).
#
# `fw doctor` printed `OK  Watchtower running` every run for six days. It checks
# liveness and identity; nothing checked currency.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="$FRAMEWORK_ROOT/lib/watchtower-staleness.sh"
    # shellcheck source=/dev/null
    . "$LIB"
    WEB="$BATS_TEST_TMPDIR/web"
    mkdir -p "$WEB/blueprints" "$WEB/__pycache__"
}

teardown() {
    [ -n "${LIVE_PID:-}" ] && kill "$LIVE_PID" 2>/dev/null
    return 0
}

# A real live process, so start-time resolution is exercised rather than mocked.
_spawn() {
    sleep 60 &
    LIVE_PID=$!
}

_age() { touch -d "@$1" "$2"; }
_now() { date +%s; }

# ── start-time resolution ────────────────────────────────────────────────────

@test "t2938: start epoch of a live process resolves to roughly now" {
    _spawn
    run watchtower_process_start_epoch "$LIVE_PID"
    [ "$status" -eq 0 ]
    local now delta
    now=$(_now)
    delta=$(( now - output ))
    [ "$delta" -ge -2 ] && [ "$delta" -le 30 ] || {
        echo "start epoch $output is $delta s from now — not a start time" >&2
        return 1
    }
}

@test "t2938: a dead pid is undeterminable, not zero" {
    # Returning 0 (epoch) instead of failing would make EVERY file newer, so the
    # check would fire constantly, be muted, and protect nothing.
    _spawn
    kill "$LIVE_PID" 2>/dev/null
    # `wait` on a SIGTERM'd child exits 143; under bats' `set -e` that aborts the
    # test before the assertion runs. Capture it — the non-zero is the expectation.
    wait "$LIVE_PID" 2>/dev/null || true
    run watchtower_process_start_epoch "$LIVE_PID"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

# ── the WARN condition ───────────────────────────────────────────────────────

@test "t2938: source older than the process is NOT stale" {
    _spawn
    _age 1000000000 "$WEB/app.py"
    run watchtower_stale_sources "$LIVE_PID" "$WEB"
    [ "$status" -ne 0 ] || { echo "warned on a process newer than its source" >&2; return 1; }
}

@test "t2938: source newer than the process IS stale and is named" {
    # The reconstruction of the live incident: inception.py edited after the
    # server started. This is the leg that must be non-vacuous — every other
    # leg here asserts the check STAYS QUIET.
    _spawn
    _age 1000000000 "$WEB/app.py"
    _age "$(( $(_now) + 60 ))" "$WEB/blueprints/inception.py"
    run watchtower_stale_sources "$LIVE_PID" "$WEB"
    [ "$status" -eq 0 ] || { echo "missed a source newer than the process" >&2; return 1; }
    echo "$output" | grep -q "blueprints/inception.py"
    echo "$output" | grep -qv "app.py" || true
}

@test "t2938: __pycache__ is excluded so the check cannot fire always" {
    # The running process writes its own .pyc files, so they are newer than it
    # by construction. Counting them would make this WARN permanent — and a
    # permanent warning is a muted one.
    _spawn
    _age 1000000000 "$WEB/app.py"
    _age "$(( $(_now) + 60 ))" "$WEB/__pycache__/app.cpython-311.pyc"
    run watchtower_stale_sources "$LIVE_PID" "$WEB"
    [ "$status" -ne 0 ] || { echo "a .pyc made the check fire: $output" >&2; return 1; }
}

@test "t2938: non-served file types do not trigger a restart nag" {
    _spawn
    _age "$(( $(_now) + 60 ))" "$WEB/README.md"
    run watchtower_stale_sources "$LIVE_PID" "$WEB"
    [ "$status" -ne 0 ]
}

@test "t2938: undeterminable start time never warns" {
    _age "$(( $(_now) + 60 ))" "$WEB/app.py"
    run watchtower_stale_sources 999999999 "$WEB"
    [ "$status" -ne 0 ] || { echo "warned without knowing when the process started" >&2; return 1; }
}

# ── wiring ───────────────────────────────────────────────────────────────────

@test "t2938: doctor actually calls the predicate" {
    # A correct predicate that nothing invokes is the shape I reported to 832 at
    # rail 559 §3: `--check` documented, called by nothing, red on the real
    # corpus — each fact hiding the other. Assert the call site, not just the lib.
    grep -q 'watchtower_stale_sources' "$FRAMEWORK_ROOT/bin/fw" || {
        echo "lib ships but doctor never calls it" >&2
        return 1
    }
    grep -q 'watchtower-staleness.sh' "$FRAMEWORK_ROOT/bin/fw"
}

@test "t2938: the WARN names a remedy the operator can run" {
    grep -q 'predates its own source' "$FRAMEWORK_ROOT/bin/fw"
    grep -q 'watchtower restart' "$FRAMEWORK_ROOT/bin/fw"
}
