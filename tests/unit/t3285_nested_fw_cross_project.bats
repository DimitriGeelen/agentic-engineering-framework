#!/usr/bin/env bats
# T-3285 (OBS-370): a nested fw invoked in a DIFFERENT project must not act on
# the outer project whose PROJECT_ROOT it inherited from fw machinery.
#
# Origin: T-3250's close gate — update-task.sh runs with PROJECT_ROOT/TASKS_DIR/
# CONTEXT_DIR/_FW_PATHS_DERIVED_BY exported (lib/paths.sh); its P-011 gate ran a
# sandbox harness whose `fw task create` inherited them all, kept the outer root
# (valid → "env wins"), and wrote 34 junk tasks into the live framework repo.
#
# The contract pinned here:
#   fw-derived provenance (sentinel == PROJECT_ROOT) + cwd in a different real
#   project → the cwd's project wins (re-anchor).
#   Anything else — no sentinel (operator-explicit env, test fixtures),
#   mismatched sentinel (override after derivation), same project, or a
#   non-project cwd (dispatch workers in /tmp) — env wins, unchanged.
#
# Surface under test: bin/fw "Resolve PROJECT_ROOT" T-3285 branch.
# Observed via `fw version` ("Project: <root>") and a real `fw task create`.

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    # OUTER: the live-repo analogue whose env leaks into the nested invocation.
    OUTER="$(mktemp -d -t fw-t3285-outer-XXXXXX)"
    mkdir -p "$OUTER/.tasks/active" "$OUTER/.context/working"
    printf 'version: test\n' > "$OUTER/.framework.yaml"

    # INNER: the sandbox analogue the nested fw is actually standing in.
    INNER="$(mktemp -d -t fw-t3285-inner-XXXXXX)"
    mkdir -p "$INNER/.tasks/active" "$INNER/.context/working"
    printf 'version: test\n' > "$INNER/.framework.yaml"

    # Neutral HOME with no marker so nothing trips the $HOME-poison signature.
    NEUTRAL_HOME="$(mktemp -d -t fw-t3285-home-XXXXXX)"

    # Non-project dir for the dispatch-worker case.
    NOWHERE="$(mktemp -d -t fw-t3285-nowhere-XXXXXX)"
}

teardown() {
    rm -rf "$OUTER" "$INNER" "$NEUTRAL_HOME" "$NOWHERE"
}

# The poisoned-env shape lib/paths.sh actually exports from an outer fw process.
_poisoned_env() {
    echo "PROJECT_ROOT=$OUTER"
    echo "TASKS_DIR=$OUTER/.tasks"
    echo "CONTEXT_DIR=$OUTER/.context"
    echo "_FW_PATHS_DERIVED_BY=$OUTER"
}

@test "t1: fw-derived inherited root + cwd in a different project → cwd project wins" {
    cd "$INNER"
    run env -u CLAUDE_PROJECT_DIR HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" TASKS_DIR="$OUTER/.tasks" CONTEXT_DIR="$OUTER/.context" \
        _FW_PATHS_DERIVED_BY="$OUTER" \
        bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$INNER"
    ! echo "$output" | grep -q "Project:.*$OUTER"
}

@test "t2: no sentinel (operator-explicit env) → env wins unconditionally, unchanged" {
    cd "$INNER"
    run env -u CLAUDE_PROJECT_DIR -u _FW_PATHS_DERIVED_BY HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" \
        bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$OUTER"
}

@test "t3: sentinel != PROJECT_ROOT (override after derivation) → env wins" {
    cd "$INNER"
    run env -u CLAUDE_PROJECT_DIR HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" _FW_PATHS_DERIVED_BY="$NOWHERE" \
        bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$OUTER"
}

@test "t4: same project (worker stays home) → no-op" {
    cd "$OUTER"
    run env -u CLAUDE_PROJECT_DIR HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" _FW_PATHS_DERIVED_BY="$OUTER" \
        bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$OUTER"
}

@test "t5: non-project cwd (dispatch worker in /tmp) → inherited root kept" {
    cd "$NOWHERE"
    run env -u CLAUDE_PROJECT_DIR HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" _FW_PATHS_DERIVED_BY="$OUTER" \
        bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$OUTER"
}

@test "t6: write-leg — task create under the full T-3250 poison lands in INNER, OUTER untouched" {
    cd "$INNER"
    run env -u CLAUDE_PROJECT_DIR HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" TASKS_DIR="$OUTER/.tasks" CONTEXT_DIR="$OUTER/.context" \
        _FW_PATHS_DERIVED_BY="$OUTER" \
        bash "$FW" task create --name "t3285 probe" --type build --owner agent \
        --description "cross-project write-leg probe"
    [ "$status" -eq 0 ]
    # the task file exists in INNER and nothing leaked into OUTER
    ls "$INNER"/.tasks/active/T-*probe*.md
    run ls "$OUTER"/.tasks/active/
    [ -z "$output" ]
}
