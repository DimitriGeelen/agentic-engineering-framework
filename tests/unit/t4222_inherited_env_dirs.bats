#!/usr/bin/env bats
# T-4222 (G-116, second source): TASKS_DIR/CONTEXT_DIR inherited from ANOTHER project, with no
# _FW_PATHS_DERIVED_BY sentinel (1023 had unset it), kept steering writes into that project:
# lib/paths.sh's `${TASKS_DIR:-…}` honoured the inherited value. Rule (task Decisions): an
# inherited TASKS_DIR/CONTEXT_DIR that lies outside the resolved PROJECT_ROOT AND is itself a
# project's own dir (its parent carries .framework.yaml) is re-derived, with a stderr warning.
# FW_TASKS_DIR_OVERRIDE=<this project root> keeps a deliberate outside value (T-4685: a bare =1
# no longer does — it cannot be told apart from an inherited one). Test fixtures (plain tmp dirs
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

@test "T-4222: FW_TASKS_DIR_OVERRIDE=<this root> keeps a deliberate outside TASKS_DIR" {
    _run_in_b FW_TASKS_DIR_OVERRIDE="$B"
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

# T-4670: the rule is containment, not the exact <proj>/.tasks shape. Each case sources lib/paths.sh
# in project B with an inherited value and reports what it resolved to.
_paths_in_b() {   # _paths_in_b <NAME=VALUE>... — env passed to the sourcing shell
    cd "$B"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM \
        -u FW_TASKS_DIR_OVERRIDE -u TASKS_DIR -u CONTEXT_DIR HOME="$HOME_N" PROJECT_ROOT="$B" "$@" \
        bash -c ". '$ROOT/lib/paths.sh'; echo \"TD=\$TASKS_DIR\"; echo \"CD=\$CONTEXT_DIR\""
}

@test "T-4670: subdir inside another project (/x/.context/working) is re-derived" {
    _paths_in_b CONTEXT_DIR="$A/.context/working"
    echo "$output"
    echo "$output" | grep -qx "CD=$B/.context"
    echo "$output" | grep -q "inherited CONTEXT_DIR=$A/.context/working lies inside another project"
}

@test "T-4670: a symlink into another project is re-derived" {
    S="$(mktemp -d -t fw-t4670-ln-XXXXXX)"; ln -s "$A/.tasks" "$S/tasks"
    _paths_in_b TASKS_DIR="$S/tasks"
    rm -rf "$S"
    echo "$output"
    echo "$output" | grep -qx "TD=$B/.tasks"
}

@test "T-4670: the exact-dir case (<other>/.tasks) is still caught" {
    _paths_in_b TASKS_DIR="$A/.tasks"
    echo "$output"
    echo "$output" | grep -qx "TD=$B/.tasks"
}

@test "T-4670: a fixture tmp dir with no project ancestor is still honoured" {
    F="$(mktemp -d -t fw-t4670-fx-XXXXXX)"; mkdir -p "$F/sub/.context"
    _paths_in_b CONTEXT_DIR="$F/sub/.context"
    rm -rf "$F"
    echo "$output"
    echo "$output" | grep -qx "CD=$F/sub/.context"
    ! echo "$output" | grep -q "inherited" || false
}

@test "T-4670: FW_TASKS_DIR_OVERRIDE=<this root> set on this invocation keeps a value inside another project" {
    _paths_in_b TASKS_DIR="$A/.tasks/active" FW_TASKS_DIR_OVERRIDE="$B"
    echo "$output"
    echo "$output" | grep -qx "TD=$A/.tasks/active"
}

# T-4685: the sentinel stripped (TermLink T-3445's deny-list) — _paths_in_b already unsets it.
@test "T-4685: bare FW_TASKS_DIR_OVERRIDE=1 with a foreign value and no sentinel is ignored, with a stderr line" {
    _paths_in_b TASKS_DIR="$A/.tasks" CONTEXT_DIR="$A/.context" FW_TASKS_DIR_OVERRIDE=1
    echo "$output"
    echo "$output" | grep -qx "TD=$B/.tasks"
    echo "$output" | grep -qx "CD=$B/.context"
    echo "$output" | grep -q "ignoring bare FW_TASKS_DIR_OVERRIDE=1"
}

@test "T-4685: FW_TASKS_DIR_OVERRIDE naming another project's root is ignored" {
    _paths_in_b TASKS_DIR="$A/.tasks" FW_TASKS_DIR_OVERRIDE="$A"
    echo "$output"
    echo "$output" | grep -qx "TD=$B/.tasks"
    echo "$output" | grep -q "ignoring FW_TASKS_DIR_OVERRIDE=$A: it does not name this project"
}

@test "T-4685: FW_TASKS_DIR_OVERRIDE naming this root via a non-literal spelling keeps both values" {
    _paths_in_b TASKS_DIR="$A/.tasks" CONTEXT_DIR="$A/.context" FW_TASKS_DIR_OVERRIDE="$B/"
    echo "$output"
    echo "$output" | grep -qx "TD=$A/.tasks"
    echo "$output" | grep -qx "CD=$A/.context"
    ! echo "$output" | grep -q "ignoring" || false
}

@test "T-4685: bare FW_TASKS_DIR_OVERRIDE=1 with a fixture dir (no project ancestor) is honoured" {
    F="$(mktemp -d -t fw-t4685-fx-XXXXXX)"; mkdir -p "$F/.tasks"
    _paths_in_b TASKS_DIR="$F/.tasks" FW_TASKS_DIR_OVERRIDE=1
    rm -rf "$F"
    echo "$output"
    echo "$output" | grep -qx "TD=$F/.tasks"
    ! echo "$output" | grep -q "ignoring" || false
}

@test "T-4685: an override naming this root survives a sentinel from another project's derivation" {
    _paths_in_b TASKS_DIR="$A/.tasks" FW_TASKS_DIR_OVERRIDE="$B" _FW_PATHS_DERIVED_BY="$A"
    echo "$output"
    echo "$output" | grep -qx "TD=$B/.tasks"
    ! echo "$output" | grep -q "ignoring" || false
}

@test "T-4670: FW_TASKS_DIR_OVERRIDE=1 inherited across a project boundary is ignored, with a stderr line" {
    _paths_in_b TASKS_DIR="$A/.tasks" FW_TASKS_DIR_OVERRIDE=1 _FW_PATHS_DERIVED_BY="$A"
    echo "$output"
    echo "$output" | grep -qx "TD=$B/.tasks"
    echo "$output" | grep -q "ignoring FW_TASKS_DIR_OVERRIDE=1 inherited from project $A"
}
