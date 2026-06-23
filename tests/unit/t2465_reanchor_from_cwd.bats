#!/usr/bin/env bats
# T-2465 — unit tests for lib/paths.sh:fw_reanchor_from_cwd (+ the hook-stdin
# wrapper). This is the SHARED resolver generalized from T-2463's inline block:
# every framework hook is wired by main's absolute path, so when it fires in a
# worktree session bin/fw resolves PROJECT_ROOT to MAIN; the resolver re-anchors
# to the project the tool actually ran in, read from the per-call stdin `cwd`.
#
# Contract:
#   cwd resolves to a project root != PROJECT_ROOT → re-anchor PROJECT_ROOT +
#     TASKS_DIR + CONTEXT_DIR + _FW_PATHS_DERIVED_BY to it
#   cwd empty / not a dir / no project above / == PROJECT_ROOT → no-op

load ../test_helper

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    MAINFIX="$(mktemp -d)"
    WTFIX="$(mktemp -d)"
    OUTSIDE="$(mktemp -d)"   # no .framework.yaml / .tasks anywhere above
    _mk_project "$MAINFIX"
    _mk_project "$WTFIX"

    # Simulate bin/fw having resolved PROJECT_ROOT to the MAIN repo.
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
    export PROJECT_ROOT="$MAINFIX"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    export PROJECT_ROOT="$MAINFIX"
    export TASKS_DIR="$MAINFIX/.tasks"
    export CONTEXT_DIR="$MAINFIX/.context"
}

teardown() {
    rm -rf "$MAINFIX" "$WTFIX" "$OUTSIDE" 2>/dev/null
}

_mk_project() {
    mkdir -p "$1/.tasks/active" "$1/.context/working"
    echo "version: test" > "$1/.framework.yaml"
}

@test "T-2465: re-anchors PROJECT_ROOT + path vars to the cwd's project root" {
    fw_reanchor_from_cwd "$WTFIX"
    [ "$PROJECT_ROOT" = "$WTFIX" ]
    [ "$TASKS_DIR" = "$WTFIX/.tasks" ]
    [ "$CONTEXT_DIR" = "$WTFIX/.context" ]
    [ "$_FW_PATHS_DERIVED_BY" = "$WTFIX" ]
}

@test "T-2465: walks up from a subdir of the worktree to its root" {
    mkdir -p "$WTFIX/lib/sub"
    fw_reanchor_from_cwd "$WTFIX/lib/sub"
    [ "$PROJECT_ROOT" = "$WTFIX" ]
}

@test "T-2465: no-op when cwd is empty" {
    fw_reanchor_from_cwd ""
    [ "$PROJECT_ROOT" = "$MAINFIX" ]
}

@test "T-2465: no-op when cwd is not a directory" {
    fw_reanchor_from_cwd "$WTFIX/does-not-exist"
    [ "$PROJECT_ROOT" = "$MAINFIX" ]
}

@test "T-2465: no-op when cwd resolves to the same root (== PROJECT_ROOT)" {
    fw_reanchor_from_cwd "$MAINFIX"
    [ "$PROJECT_ROOT" = "$MAINFIX" ]
    [ "$TASKS_DIR" = "$MAINFIX/.tasks" ]
}

@test "T-2465: no-op when cwd is outside any project" {
    fw_reanchor_from_cwd "$OUTSIDE"
    [ "$PROJECT_ROOT" = "$MAINFIX" ]
}

@test "T-2465: resolves via .tasks dir when .framework.yaml absent" {
    local only_tasks; only_tasks="$(mktemp -d)"
    mkdir -p "$only_tasks/.tasks"
    fw_reanchor_from_cwd "$only_tasks"
    [ "$PROJECT_ROOT" = "$only_tasks" ]
    rm -rf "$only_tasks"
}

@test "T-2465: fw_reanchor_from_hook_stdin extracts cwd from JSON and re-anchors" {
    fw_reanchor_from_hook_stdin "{\"tool_name\":\"Bash\",\"cwd\":\"$WTFIX\"}"
    [ "$PROJECT_ROOT" = "$WTFIX" ]
}

@test "T-2465: fw_reanchor_from_hook_stdin no-op when JSON has no cwd key" {
    fw_reanchor_from_hook_stdin "{\"tool_name\":\"Bash\"}"
    [ "$PROJECT_ROOT" = "$MAINFIX" ]
}

@test "T-2465: fw_reanchor_from_hook_stdin no-op on malformed JSON" {
    fw_reanchor_from_hook_stdin "not json at all"
    [ "$PROJECT_ROOT" = "$MAINFIX" ]
}
