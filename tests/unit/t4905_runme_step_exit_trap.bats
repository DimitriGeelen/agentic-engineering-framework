#!/usr/bin/env bats
# T-4905 (dimitri-mint-dev P-025): a runme step that sets its own EXIT trap (the
# mount/umount cleanup idiom) used to replace runme's EXIT trap, so the run ended with no
# RUNME EXIT, no exit event and its last output lost. Steps now run in one subshell.

setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
}

teardown() { rm -rf "$TMPP"; }

_run() {   # <name> <commands...>
    local name="$1"; shift
    "$FW" runme new "$name" -- "$@" >/dev/null
    run bash "$TMPP/.context/runme/$name/runme.sh"
    sleep 0.5
    LOG="$TMPP/.context/runme/$name/run.log"
}

@test "the P-025 repro logs body, cleanup and RUNME EXIT 0" {
    _run repro 'trap "echo cleanup" EXIT; echo body'
    [ "$status" -eq 0 ]
    grep -q " body$" "$LOG"
    grep -q " cleanup$" "$LOG"
    grep -q "RUNME EXIT 0" "$LOG"
    grep -q '"event":"exit"' "$TMPP/.context/runme/events.jsonl"
}

@test "a failing step after the user's trap still runs the cleanup and records the failure" {
    _run fails 'trap "echo cleanup" EXIT' 'false' 'echo never'
    [ "$status" -ne 0 ]
    grep -q " cleanup$" "$LOG"
    grep -q "RUNME EXIT 1" "$LOG"
    ! grep -q " never$" "$LOG"
}

@test "cd in step 1 still applies in step 2" {
    mkdir -p "$TMPP/sub"
    _run cdcarry "cd $TMPP/sub" 'pwd'
    [ "$status" -eq 0 ]
    grep -q " $TMPP/sub$" "$LOG"
}

@test "an exported variable carries across steps" {
    _run envcarry 'export T4905_X=carried' 'echo "x=$T4905_X"'
    [ "$status" -eq 0 ]
    grep -q " x=carried$" "$LOG"
}

@test "an explicit exit N in a step is the run's exit code" {
    _run exitn 'exit 3'
    [ "$status" -eq 3 ]
    grep -q "RUNME EXIT 3" "$LOG"
}
