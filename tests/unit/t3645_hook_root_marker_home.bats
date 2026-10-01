#!/usr/bin/env bats
# T-3645 — a marker-bearing home must never become PROJECT_ROOT for a hook.
# Ported from 055-agentic-fleet-cockpit T-349 / pickup P-008 (OBS-071): after a
# `cd` into a scratch dir under /root/.claude/jobs/…, every tool call was refused
# with a false "No active task", because /root carries .framework.yaml + .tasks
# and bin/fw settled on it via two paths:
#   H2  CLAUDE_PROJECT_DIR unusable → the find_project_root fallback result was
#       never staleness-checked;
#   H3  CLAUDE_PROJECT_DIR valid, HOME unset/different → _project_root_is_stale
#       compared only against $HOME, so the home read as a genuine other project
#       and T-2446's cwd-wins rule picked it.
# The home fixture is INITIALISED (.context/working/focus.yaml): an uninitialised
# marker dir makes check-active-task fail open, so a naive fixture passes vacuously.

load ../test_helper

REPO="$BATS_TEST_DIRNAME/../.."

_init_project() {   # dir — a framework project with focus cleared
    mkdir -p "$1/.tasks/active" "$1/.context/working"
    printf 'version: test\n' > "$1/.framework.yaml"
    printf 'current_task: null\n' > "$1/.context/working/focus.yaml"
    printf 'session_id: S-test\n' > "$1/.context/working/session.yaml"
}

setup() {
    TMP="$(mktemp -d)"
    HOME_FX="$TMP/home"
    _init_project "$HOME_FX"
    SCRATCH="$HOME_FX/.claude/jobs/x/tmp"
    mkdir -p "$SCRATCH"

    # PROJ: a consumer with a VENDORED fw — a real copy of bin/fw (so FW_BIN_DIR
    # resolves inside PROJ) with the rest of the framework symlinked in.
    PROJ="$TMP/proj"
    _init_project "$PROJ"
    mkdir -p "$PROJ/.agentic-framework/bin"
    cp "$REPO/bin/fw" "$PROJ/.agentic-framework/bin/fw"
    local e
    for e in FRAMEWORK.md VERSION agents lib policy web; do
        [ -e "$REPO/$e" ] && ln -s "$(cd "$REPO" && pwd)/$e" "$PROJ/.agentic-framework/$e"
    done
    touch "$PROJ/.agentic-framework/.fw-not-a-project"
    VFW="$PROJ/.agentic-framework/bin/fw"
}

teardown() {
    [ -d "${TMP:-}" ] && rm -rf "$TMP"
}

_project_of() {    # print the "Project:" line value from `fw version` output
    echo "$1" | sed -n 's/^Project:[[:space:]]*//p' | head -1
}

@test "H2: CLAUDE_PROJECT_DIR unusable, cwd under a marker home → the vendoring project wins" {
    cd "$SCRATCH"
    run env -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY \
        HOME="$HOME_FX" CLAUDE_PROJECT_DIR="$SCRATCH" bash "$VFW" version
    echo "resolved: $(_project_of "$output")"
    [ "$status" -eq 0 ]
    [ "$(_project_of "$output")" = "$PROJ" ]
}

@test "H2: CLAUDE_PROJECT_DIR unset, cwd under a marker home → the vendoring project wins" {
    cd "$SCRATCH"
    run env -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u CLAUDE_PROJECT_DIR \
        HOME="$HOME_FX" bash "$VFW" version
    echo "resolved: $(_project_of "$output")"
    [ "$status" -eq 0 ]
    [ "$(_project_of "$output")" = "$PROJ" ]
}

@test "H3: HOME unset, cwd in the passwd home (with markers) → CLAUDE_PROJECT_DIR wins" {
    local pw_home
    pw_home=$(python3 -c 'import os,pwd; print(os.path.realpath(pwd.getpwuid(os.getuid()).pw_dir))')
    { [ -f "$pw_home/.framework.yaml" ] || [ -d "$pw_home/.tasks" ]; } \
        || skip "this host's passwd home carries no framework markers"
    cd "$pw_home"
    run env -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u HOME \
        CLAUDE_PROJECT_DIR="$PROJ" bash "$REPO/bin/fw" version
    echo "resolved: $(_project_of "$output")"
    [ "$status" -eq 0 ]
    [ "$(_project_of "$output")" = "$PROJ" ]
}

@test "H3: HOME points elsewhere, cwd in the passwd home (with markers) → CLAUDE_PROJECT_DIR wins" {
    local pw_home
    pw_home=$(python3 -c 'import os,pwd; print(os.path.realpath(pwd.getpwuid(os.getuid()).pw_dir))')
    { [ -f "$pw_home/.framework.yaml" ] || [ -d "$pw_home/.tasks" ]; } \
        || skip "this host's passwd home carries no framework markers"
    cd "$pw_home"
    run env -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY \
        HOME="$TMP" CLAUDE_PROJECT_DIR="$PROJ" bash "$REPO/bin/fw" version
    echo "resolved: $(_project_of "$output")"
    [ "$status" -eq 0 ]
    [ "$(_project_of "$output")" = "$PROJ" ]
}

@test "T-2446 pinned: cwd inside a genuine OTHER project still wins over CLAUDE_PROJECT_DIR" {
    local other="$TMP/other"
    _init_project "$other"
    cd "$other"
    run env -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY \
        HOME="$HOME_FX" CLAUDE_PROJECT_DIR="$PROJ" bash "$REPO/bin/fw" version
    echo "resolved: $(_project_of "$output")"
    [ "$status" -eq 0 ]
    [ "$(_project_of "$output")" = "$other" ]
}

@test "the 'No active task' block names the project root and focus file it read" {
    cd "$SCRATCH"
    run env -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY \
        HOME="$HOME_FX" CLAUDE_PROJECT_DIR="$PROJ" bash "$VFW" hook check-active-task \
        <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$PROJ/src.txt\",\"old_string\":\"a\",\"new_string\":\"b\"}}"
    [ "$status" -eq 2 ]
    [[ "$output" == *"No active task"* ]]
    [[ "$output" == *"project root: $PROJ"* ]]
    [[ "$output" == *"$PROJ/.context/working/focus.yaml"* ]]
}
