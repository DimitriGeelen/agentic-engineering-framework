#!/usr/bin/env bats
# T-4222 (G-116, second source): TASKS_DIR/CONTEXT_DIR inherited from ANOTHER project, with no
# _FW_PATHS_DERIVED_BY sentinel (1023 had unset it), kept steering writes into that project:
# lib/paths.sh's `${TASKS_DIR:-…}` honoured the inherited value. Rule (task Decisions): an
# inherited TASKS_DIR/CONTEXT_DIR that lies outside the resolved PROJECT_ROOT AND is itself a
# project's own dir (its parent carries .framework.yaml) is re-derived, with a stderr warning.
# FW_TASKS_DIR_OVERRIDE=1 keeps a deliberate outside value. Test fixtures (plain tmp dirs
# without .framework.yaml) are untouched.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    A="$(mktemp -d -t fw-t4222-A-XXXXXX)"; B="$(mktemp -d -t fw-t4222-B-XXXXXX)"
    for p in "$A" "$B"; do
        mkdir -p "$p/.tasks/active" "$p/.tasks/completed" "$p/.context/working"
        printf 'version: test\n' > "$p/.framework.yaml"
    done
    HOME_N="$(mktemp -d -t fw-t4222-home-XXXXXX)"
}
teardown() { rm -rf "$A" "$B" "$HOME_N"; }

_run_in_b() {
    cd "$B"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM \
        -u CLAUDE_PROJECT_DIR HOME="$HOME_N" TASKS_DIR="$A/.tasks" CONTEXT_DIR="$A/.context" "$@" \
        bash "$ROOT/bin/fw" task create --name "t4222 probe" --type build --owner agent --description "t4222 probe"
}

@test "T-4222: inherited foreign TASKS_DIR/CONTEXT_DIR (no sentinel) do not steer task create into the other project" {
    _run_in_b
    if ls "$A/.tasks/active"/T-*.md >/dev/null 2>&1; then echo "leaked into A:"; ls "$A/.tasks/active"; echo "$output"; false; fi
    ls "$B/.tasks/active"/T-*.md >/dev/null 2>&1 || { echo "$output"; false; }
    echo "$output" | grep -q "inherited TASKS_DIR=$A/.tasks"
}

@test "T-4222: FW_TASKS_DIR_OVERRIDE=1 keeps a deliberate outside TASKS_DIR" {
    _run_in_b FW_TASKS_DIR_OVERRIDE=1
    ls "$A/.tasks/active"/T-*.md >/dev/null 2>&1 || { echo "$output"; false; }
}

@test "T-4222: a plain tmp-dir fixture (no .framework.yaml) outside PROJECT_ROOT stays honoured" {
    F="$(mktemp -d -t fw-t4222-fx-XXXXXX)"; mkdir -p "$F/.tasks/active"
    cd "$B"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM \
        HOME="$HOME_N" TASKS_DIR="$F/.tasks" bash -c ". '$ROOT/lib/paths.sh'; echo \"TD=\$TASKS_DIR\""
    echo "$output" | grep -qx "TD=$F/.tasks"
    rm -rf "$F"
}
