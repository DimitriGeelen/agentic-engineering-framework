#!/usr/bin/env bats
# T-3651 — `fw termlink cleanup` must parse its arguments before touching anything,
# offer --dry-run, and never destroy uncollected results or SIGTERM an orphan without consent.
# Every test runs on a fixture FW_DISPATCH_DIR, never the real /tmp/tl-dispatch.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../../agents/termlink/termlink.sh"
    D="$(mktemp -d)/dispatch"
    mkdir -p "$D"
    export FW_DISPATCH_DIR="$D"
    ORPHAN_PID=""
}

teardown() {
    [ -n "$ORPHAN_PID" ] && kill "$ORPHAN_PID" 2>/dev/null || true
    rm -rf "$(dirname "$D")"
}

mk_finished() {  # name [collected]
    mkdir -p "$D/$1"
    echo 0 > "$D/$1/exit_code"
    echo "result text" > "$D/$1/result.md"
    [ "${2:-}" = collected ] && date > "$D/$1/collected"
    return 0
}

cl() { run bash "$SCRIPT" cleanup "$@" < /dev/null; }

@test "--help and -h print usage, exit 0, touch nothing" {
    mk_finished w1
    for f in --help -h; do
        cl "$f"
        [ "$status" -eq 0 ]
        [[ "$output" == *"Usage: fw termlink cleanup"* ]]
        [ -f "$D/w1/result.md" ]
    done
}

@test "unknown flag and typo exit 2 and touch nothing" {
    mk_finished w1
    cl --dry-runn
    [ "$status" -eq 2 ]
    cl --bogus
    [ "$status" -eq 2 ]
    [ -f "$D/w1/result.md" ]
}

@test "--dry-run and -n list the plan and change nothing" {
    mk_finished w1
    mk_finished w2 collected
    for f in --dry-run -n; do
        cl "$f"
        [ "$status" -eq 0 ]
        [[ "$output" == *"remove w1"*"UNCOLLECTED"* ]]
        [[ "$output" == *"remove w2"* ]]
        [[ "$output" == *"Dry run"* ]]
    done
    [ -f "$D/w1/result.md" ]
    [ -f "$D/w2/result.md" ]
}

@test "non-tty without --yes refuses with exit 3 and leaves uncollected results" {
    mk_finished w1
    cl
    [ "$status" -eq 3 ]
    [ -f "$D/w1/result.md" ]
    [ -f "$D/w1/exit_code" ]
}

@test "--yes removes finished workers" {
    mk_finished w1
    mk_finished w2 collected
    cl --yes
    [ "$status" -eq 0 ]
    [ ! -e "$D/w1" ]
    [ ! -e "$D/w2" ]
}

@test "active/unfinalised worker dir always survives, even with --yes" {
    mk_finished w1
    mkdir -p "$D/act"                       # no exit_code, no process: kept (T-3595)
    mk_finished rev
    touch "$D/rev/finalise_required"        # review worker not yet finalised (T-3580)
    cl --yes
    [ "$status" -eq 0 ]
    [ ! -e "$D/w1" ]
    [ -d "$D/act" ]
    [ -f "$D/rev/result.md" ]
}

@test "no SIGTERM before consent: refused and dry runs leave the orphan alive" {
    mkdir -p "$D/orph"
    bash -c 'sleep 300; :' "$D/orph/" >/dev/null 2>&1 3>&- &
    ORPHAN_PID=$!
    sleep 0.3
    cl --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would SIGTERM"* ]]
    kill -0 "$ORPHAN_PID"
    cl
    [ "$status" -eq 3 ]
    kill -0 "$ORPHAN_PID"
    [ -d "$D/orph" ]
}

@test "with --yes the orphan is terminated after consent" {
    mkdir -p "$D/orph"
    bash -c 'sleep 300; :' "$D/orph/" >/dev/null 2>&1 3>&- &
    ORPHAN_PID=$!
    sleep 0.3
    cl --yes
    [ "$status" -eq 0 ]
    sleep 0.3
    if kill -0 "$ORPHAN_PID" 2>/dev/null; then false; fi
    [ ! -e "$D/orph" ]
}
