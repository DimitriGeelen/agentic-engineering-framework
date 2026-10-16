#!/usr/bin/env bats
# T-4218 (G-116): an inherited PROJECT_ROOT names another project. A tmux server polluted by one
# project's dispatch handed its paths to every session started on it; fw and its hooks then acted
# on that project. Rule (see the task Decisions): a LEAKED root — one carrying fw's own sentinel
# _FW_PATHS_DERIVED_BY — that is not the caller's project is replaced by the caller's project,
# with a loud stderr warning. "The caller's project" is the cwd's project, else a valid
# CLAUDE_PROJECT_DIR. An explicit `PROJECT_ROOT=/x fw …` prefix carries no sentinel and is
# honoured unchanged (cross-project use keeps working).

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    OUTER="$(mktemp -d -t fw-t4218-outer-XXXXXX)"
    mkdir -p "$OUTER/.tasks/active" "$OUTER/.context/working"
    printf 'version: test\n' > "$OUTER/.framework.yaml"
    INNER="$(mktemp -d -t fw-t4218-inner-XXXXXX)"
    mkdir -p "$INNER/.tasks/active" "$INNER/.context/working"
    printf 'version: test\n' > "$INNER/.framework.yaml"
    NEUTRAL_HOME="$(mktemp -d -t fw-t4218-home-XXXXXX)"
    NOWHERE="$(mktemp -d -t fw-t4218-nowhere-XXXXXX)"
}

teardown() {
    rm -rf "$OUTER" "$INNER" "$NEUTRAL_HOME" "$NOWHERE"
}

@test "t4218-b: a leaked foreign root is replaced by the cwd project, with a loud warning" {
    cd "$INNER"
    run env -u CLAUDE_PROJECT_DIR HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" _FW_PATHS_DERIVED_BY="$OUTER" \
        bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$INNER"
    if echo "$output" | grep -q "Project:.*$OUTER"; then false; fi
    # the replacement is announced on stderr (run merges it into output)
    echo "$output" | grep -q "inherited PROJECT_ROOT=$OUTER"
}

@test "t4218-c: a leaked foreign root loses to CLAUDE_PROJECT_DIR when the cwd is in no project (hook case)" {
    cd "$NOWHERE"
    run env HOME="$NEUTRAL_HOME" CLAUDE_PROJECT_DIR="$INNER" \
        PROJECT_ROOT="$OUTER" _FW_PATHS_DERIVED_BY="$OUTER" \
        bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$INNER"
    if echo "$output" | grep -q "Project:.*$OUTER"; then false; fi
}

@test "t4218-d: an explicit PROJECT_ROOT prefix (no sentinel) is honoured even with CLAUDE_PROJECT_DIR set" {
    cd "$NOWHERE"
    run env -u _FW_PATHS_DERIVED_BY HOME="$NEUTRAL_HOME" CLAUDE_PROJECT_DIR="$INNER" \
        PROJECT_ROOT="$OUTER" \
        bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$OUTER"
}

# claude-fw pins the session's project to the one it is launched in. A fake `claude` on PATH records
# the environment it is started with; the tmux wrap is off (FW_CLAUDE_FW_NO_TMUX) so no server is
# involved. Inherited values name another project (the G-116 shape).
@test "t4218-a: claude-fw starts its session with its own launch project, not an inherited foreign one" {
    CFW="$BATS_TEST_DIRNAME/../../bin/claude-fw"
    W="$(mktemp -d -t fw-t4218-cfw-XXXXXX)"
    mkdir -p "$W/bin" "$W/proj/.tasks/active" "$W/proj/.context/working"
    printf 'version: test\n' > "$W/proj/.framework.yaml"
    printf '#!/bin/bash\nenv > %q\nexit 0\n' "$W/claude.env" > "$W/bin/claude"
    chmod +x "$W/bin/claude"
    PROJ_CANON="$(cd "$W/proj" && pwd -P)"
    cd "$W/proj"
    run env -u TMUX -u TL_CLAUDE_ENABLED -u FW_DISPATCHED_WORKER \
        PATH="$W/bin:$PATH" FW_CLAUDE_FW_NO_TMUX=1 FW_NO_TERMINATOR=1 CLAUDE_FW_NO_SIDECAR=1 \
        PROJECT_ROOT="$OUTER" FRAMEWORK_ROOT="$OUTER/.agentic-framework" \
        _FW_PATHS_DERIVED_BY="$OUTER" TASKS_DIR="$OUTER/.tasks" CONTEXT_DIR="$OUTER/.context" \
        bash "$CFW" --no-restart </dev/null
    [ -s "$W/claude.env" ] || { echo "claude was not started"; false; }
    grep -qx "PROJECT_ROOT=$PROJ_CANON" "$W/claude.env"
    if grep -qx "PROJECT_ROOT=$OUTER" "$W/claude.env"; then false; fi
    if grep -qx "FRAMEWORK_ROOT=$OUTER/.agentic-framework" "$W/claude.env"; then false; fi
    # the replacement is said out loud, not silently
    echo "$output" | grep -q "inherited PROJECT_ROOT=$OUTER is not this project"
    rm -rf "$W"
}
