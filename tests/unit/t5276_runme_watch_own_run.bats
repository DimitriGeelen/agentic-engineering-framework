#!/usr/bin/env bats
# T-5276 (0506-Voxtype-extention msg 293168af, proposal C): `fw runme watch` reported a
# run that had not happened. (1) A runme rebuilt under the same name after a failed run
# was reported "finished (exit 1)" at once, from the previous run.log. (2) A runme whose
# script runs another runme was reported finished at the inner runme's RUNME EXIT.
# The watch is now bound to the run id `new` writes, and `new` rotates the old log.

setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
    D="$TMPP/.context/runme"
}

teardown() {
    touch "$TMPP/go" 2>/dev/null
    [ -n "${BG:-}" ] && { wait "$BG" 2>/dev/null || true; }
    rm -rf "$TMPP"
}

_wait_for() {   # <pattern> <file>
    local i=0
    until grep -q "$1" "$2" 2>/dev/null; do i=$((i + 1)); [ "$i" -lt 100 ] || return 1; sleep 0.1; done
}

@test "stale log: a rebuilt runme is not reported from the previous run's EXIT" {
    "$FW" runme new redo -- 'exit 1' >/dev/null
    run bash "$D/redo/runme.sh"
    [ "$status" -eq 1 ]
    sleep 0.4
    "$FW" runme new redo -- 'echo second-build' >/dev/null
    # nothing has been run since the rebuild
    run "$FW" runme watch redo --timeout 2
    [ "$status" -eq 124 ]
    [[ "$output" == *"not started"* ]]
    [[ "$output" != *"finished"* ]]
    # now the operator runs it: the watch reports THIS run
    bash "$D/redo/runme.sh" >/dev/null 2>&1; sleep 0.4
    run "$FW" runme watch redo --timeout 10
    [ "$status" -eq 0 ]
    [[ "$output" == *"second-build"* ]]
    [[ "$output" == *"redo finished (exit 0)"* ]]
}

@test "stale log: new rotates the previous run.log so a reader sees no old run" {
    "$FW" runme new rot -- 'echo first-build' >/dev/null
    bash "$D/rot/runme.sh" >/dev/null 2>&1; sleep 0.4
    "$FW" runme new rot -- 'echo second-build' >/dev/null
    [ ! -e "$D/rot/run.log" ]
    grep -q "first-build" "$D/rot/run.log.1"
    grep -q "RUNME EXIT 0" "$D/rot/run.log.1"
}

@test "nested: an inner runme's EXIT does not end the outer watch" {
    "$FW" runme new inner -- 'echo inner-body' >/dev/null
    "$FW" runme new outer -- "bash '$D/inner/runme.sh'" "until [ -f '$TMPP/go' ]; do sleep 0.1; done" 'echo after-inner' >/dev/null
    bash "$D/outer/runme.sh" >/dev/null 2>&1 3>&- & BG=$!
    _wait_for "RUNME EXIT 0" "$D/outer/run.log"      # the INNER exit, relayed into the outer log
    ! grep -q "after-inner" "$D/outer/run.log" || false
    run "$FW" runme watch outer --timeout 2
    [ "$status" -eq 124 ]
    [[ "$output" == *"still running"* ]]
    [[ "$output" != *"finished"* ]]
    touch "$TMPP/go"
    run "$FW" runme watch outer --timeout 20
    [ "$status" -eq 0 ]
    [[ "$output" == *"after-inner"* ]]
    [[ "$output" == *"outer finished (exit 0)"* ]]
}

@test "nested: the outer watch returns the outer exit code, not the inner one" {
    "$FW" runme new bad -- 'exit 3' >/dev/null
    "$FW" runme new wrap -- "bash '$D/bad/runme.sh' || true" 'echo wrap-done' >/dev/null
    bash "$D/wrap/runme.sh" >/dev/null 2>&1; sleep 0.4
    grep -q "RUNME EXIT 3" "$D/wrap/run.log"
    run "$FW" runme watch wrap --timeout 10
    [ "$status" -eq 0 ]
    [[ "$output" == *"wrap finished (exit 0)"* ]]
}

@test "markers stay parseable: START and EXIT keep their old prefix and carry the run id" {
    "$FW" runme new fmt -- 'echo hi' >/dev/null
    rid=$(cat "$D/fmt/run.id")
    [ -n "$rid" ]
    bash "$D/fmt/runme.sh" >/dev/null 2>&1; sleep 0.4
    grep -qE "^[0-9:]{8} RUNME START fmt [0-9TZ:-]+ user=.* id=$rid\$" "$D/fmt/run.log"
    grep -qE "^[0-9:]{8} RUNME EXIT 0 id=$rid\$" "$D/fmt/run.log"
    [ "$(grep -o 'RUNME EXIT [0-9]*' "$D/fmt/run.log" | awk '{print $3}')" = 0 ]
}

@test "a rebuild gets a new run id" {
    "$FW" runme new twice -- 'echo a' >/dev/null
    a=$(cat "$D/twice/run.id")
    "$FW" runme new twice -- 'echo b' >/dev/null
    [ "$a" != "$(cat "$D/twice/run.id")" ]
}

@test "a runme generated before run ids (no run.id) is still watched by its markers" {
    mkdir -p "$D/old"
    printf '10:00:00 RUNME START old 2026-10-20T10:00:00Z user=op host=h\n10:00:01 RUNME EXIT 4\n' > "$D/old/run.log"
    run "$FW" runme watch old --timeout 4
    [ "$status" -eq 4 ]
    [[ "$output" == *"old finished (exit 4)"* ]]
}

@test "pending: an inner EXIT relayed into the outer log does not make the outer run look ended" {
    "$FW" runme new pend -- "bash '$D/none/runme.sh' || true" "until [ -f '$TMPP/go' ]; do sleep 0.1; done" >/dev/null
    "$FW" runme new none -- 'echo x' >/dev/null
    bash "$D/pend/runme.sh" >/dev/null 2>&1 3>&- & BG=$!
    _wait_for "RUNME EXIT 0" "$D/pend/run.log"       # inner exit relayed; outer still running
    run "$FW" runme pending
    [[ "$output" == *"RUN IN FLIGHT  pend"* ]]
}
