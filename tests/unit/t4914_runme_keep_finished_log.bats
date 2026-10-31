#!/usr/bin/env bats
# T-4914 (ring20-dashboard msg 21ce0bab, their T-2585): a runme started again about a
# minute after the first run finished emptied run.log, so the log of the run that did
# the work was gone. A re-run now rotates the finished log (run.log.1 .. .3) first.

setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
    D="$TMPP/.context/runme"
}

teardown() {
    [ -n "${BG:-}" ] && kill "$BG" 2>/dev/null; touch "$TMPP/go" 2>/dev/null
    wait 2>/dev/null || true
    rm -rf "$TMPP"
}

_run_once() {   # <name> <marker>
    MARK="$2" bash "$D/$1/runme.sh" >/dev/null 2>&1
    sleep 0.4
}

@test "a re-run keeps the finished run's log as run.log.1" {
    "$FW" runme new again -- 'echo "pass-$MARK"' >/dev/null
    _run_once again one
    _run_once again two
    grep -q " pass-two$" "$D/again/run.log"
    ! grep -q "pass-one" "$D/again/run.log" || false
    grep -q " pass-one$" "$D/again/run.log.1"
    grep -q "RUNME EXIT 0" "$D/again/run.log.1"
    [ "$(grep -c 'RUNME START' "$D/again/run.log")" -eq 1 ]
}

@test "three generations are kept and the fourth is dropped" {
    "$FW" runme new gens -- 'echo "pass-$MARK"' >/dev/null
    for m in a b c d e; do _run_once gens "$m"; done
    grep -q " pass-e$" "$D/gens/run.log"
    grep -q " pass-d$" "$D/gens/run.log.1"
    grep -q " pass-c$" "$D/gens/run.log.2"
    grep -q " pass-b$" "$D/gens/run.log.3"
    [ ! -e "$D/gens/run.log.4" ]
    ! grep -rq "pass-a" "$D/gens/" || false
}

@test "a first run creates no rotated copy" {
    "$FW" runme new first -- 'echo hi' >/dev/null
    _run_once first x
    [ -s "$D/first/run.log" ]
    [ ! -e "$D/first/run.log.1" ]
}

@test "a start refused by the lock (T-4871) rotates nothing" {
    "$FW" runme new busy -- 'echo first-body' "until [ -f '$TMPP/go' ]; do sleep 0.1; done" >/dev/null
    bash "$D/busy/runme.sh" >/dev/null 2>&1 3>&- & BG=$!
    local i=0
    until grep -q "first-body" "$D/busy/run.log" 2>/dev/null; do i=$((i + 1)); [ "$i" -lt 100 ]; sleep 0.1; done
    run bash "$D/busy/runme.sh"
    [ "$status" -eq 75 ]
    [ ! -e "$D/busy/run.log.1" ]
    grep -q "first-body" "$D/busy/run.log"
    touch "$TMPP/go"; wait "$BG"; BG=""
}
