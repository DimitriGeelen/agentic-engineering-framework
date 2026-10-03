#!/usr/bin/env bats
# T-3675: fw runme — operator command handoff as one logged line.

# bin/fw resolves PROJECT_ROOT itself (it would write into the real repo), so the
# behaviour tests drive lib/runme.sh directly against a temp project; one test
# below pins that bin/fw routes `runme` to the same library.
setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
}

teardown() { rm -rf "$TMPP"; }

@test "bin/fw routes runme to lib/runme.sh" {
    run "$BATS_TEST_DIRNAME/../../bin/fw" runme path routing-check
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "/.context/runme/routing-check/runme.sh$"
}

@test "new writes an executable script and prints one bash line with the absolute path" {
    run "$FW" runme new demo --desc "test" -- 'echo hello' 'echo second'
    [ "$status" -eq 0 ]
    [ -x "$TMPP/.context/runme/demo/runme.sh" ]
    echo "$output" | grep -qx "  bash $TMPP/.context/runme/demo/runme.sh"
}

@test "running the script logs START, each command, its output and EXIT 0" {
    "$FW" runme new ok -- 'echo hello-out' >/dev/null
    bash "$TMPP/.context/runme/ok/runme.sh" >/dev/null 2>&1
    sleep 0.5
    log="$TMPP/.context/runme/ok/run.log"
    grep -q "RUNME START ok" "$log"
    grep -q "+ echo hello-out" "$log"
    grep -q "hello-out" "$log"
    grep -q "RUNME EXIT 0" "$log"
}

@test "a failing command stops the script and its exit code is logged and returned by watch" {
    "$FW" runme new bad -- 'echo before' 'false' 'echo never-reached' >/dev/null
    run bash "$TMPP/.context/runme/bad/runme.sh"
    [ "$status" -ne 0 ]
    sleep 0.5
    log="$TMPP/.context/runme/bad/run.log"
    grep -q "RUNME EXIT 1" "$log"
    if grep -q "^[0-9:]* never-reached" "$log"; then false; fi
    run "$FW" runme watch bad --timeout 10
    [ "$status" -eq 1 ]
}

@test "watch returns 0 for a successful run and 124 when nothing starts" {
    "$FW" runme new good -- 'true' >/dev/null
    bash "$TMPP/.context/runme/good/runme.sh" >/dev/null 2>&1
    sleep 0.5
    run "$FW" runme watch good --timeout 10
    [ "$status" -eq 0 ]
    "$FW" runme new idle -- 'true' >/dev/null
    run "$FW" runme watch idle --timeout 2
    [ "$status" -eq 124 ]
}

@test "commands with quotes and dollar signs are echoed literally and executed" {
    "$FW" runme new q -- 'X=abc; echo "val=$X"' >/dev/null
    bash "$TMPP/.context/runme/q/runme.sh" >/dev/null 2>&1
    sleep 0.5
    log="$TMPP/.context/runme/q/run.log"
    grep -qF '+ X=abc; echo "val=$X"' "$log"
    grep -q "val=abc" "$log"
}

@test "bad names and missing commands are refused with exit 2" {
    run "$FW" runme new "../x" -- 'true'
    [ "$status" -eq 2 ]
    run "$FW" runme new nocmd
    [ "$status" -eq 2 ]
}

@test "T-3767: --help after any verb prints usage and returns at once" {
    for v in new watch path; do
        run timeout 5 "$FW" runme "$v" --help
        [ "$status" -eq 0 ]
        [[ "$output" == *"fw runme watch"* ]]
    done
    [ ! -e "$TMPP/.context/runme/--help" ]
}

@test "T-3767: a name starting with a dash is refused by every verb" {
    run "$FW" runme new -x -- 'true'
    [ "$status" -eq 2 ]
    run timeout 5 "$FW" runme watch -x
    [ "$status" -eq 2 ]
    run "$FW" runme path -x
    [ "$status" -ne 0 ]
}
