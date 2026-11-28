#!/usr/bin/env bats
# T-5420 (050 item 7, operator ruling 2026-11-28): a workflow-mode commit
# (`WM-00N: …`) is accepted by the commit-msg hook when every staged path is under
# .context/, and refused, naming the paths, when any is not. Exercised through the
# REAL installed hook in a scratch repo, not by reading the template.

load ../test_helper

setup() {
    TEST_TMP="$(mktemp -d)"
    P="$TEST_TMP/proj"
    mkdir -p "$P/.context/handovers" "$P/src"
    git -C "$P" init -q
    git -C "$P" config user.email test@local
    git -C "$P" config user.name test
    PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    [ -f "$P/.git/hooks/commit-msg" ]
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_hook() {   # run the installed commit-msg hook on a message, from inside the repo
    printf '%s\n' "$1" > "$TEST_TMP/msg"
    run bash -c "cd '$P' && .git/hooks/commit-msg '$TEST_TMP/msg'"
}

@test "t5420: installed commit-msg carries the WM rule and the bumped marker" {
    grep -q 'T-5420' "$P/.git/hooks/commit-msg"
    grep -q '^# VERSION=1.24' "$P/.git/hooks/commit-msg"
}

@test "t5420: WM-003 subject with only .context/ staged is accepted" {
    echo "handover" > "$P/.context/handovers/S-1.md"
    git -C "$P" add .context/handovers/S-1.md
    _hook "WM-003: session handover"
    [ "$status" -eq 0 ]
}

@test "t5420: WM-003 subject with a file outside .context/ is refused and names it" {
    echo "handover" > "$P/.context/handovers/S-1.md"
    echo "code" > "$P/src/app.py"
    git -C "$P" add .context/handovers/S-1.md src/app.py
    _hook "WM-003: session handover"
    [ "$status" -eq 1 ]
    [[ "$output" == *"may only change files under .context/"* ]]
    [[ "$output" == *"src/app.py"* ]]
    [[ "$output" != *".context/handovers/S-1.md"* ]]
}

@test "t5420: WM not at the start of the subject does not qualify" {
    echo "x" > "$P/.context/handovers/S-1.md"
    git -C "$P" add .context/handovers/S-1.md
    _hook "handover for WM-003: session"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No task reference found"* ]]
}
