#!/usr/bin/env bats
# T-4879: a consumer session that inherits ANOTHER consumer's environment must
# not create tasks or set focus in that other project.
#
# Origin: 1023-portable-encrypted-chromium-vault (vendored v1.6.15) ran
# `fw work-on` in a session whose environment came from 055 (a supervised
# claude-fw relaunch): PROJECT_ROOT, FRAMEWORK_ROOT (055's vendored copy),
# _FW_PATHS_DERIVED_BY, FW_ROUTED_FROM, FW_CLAUDE_FW_SUPERVISED=1. Tasks and
# focus landed in 055. With those unset it still wrote into 055: the inherited
# TASKS_DIR/CONTEXT_DIR, which T-2289 could no longer judge without the sentinel.
#
# Closed since v1.6.15 by T-3285 (v1.7.0: fw-leaked PROJECT_ROOT re-anchors to
# the cwd's project) and T-4222 (v1.8.11: an inherited TASKS_DIR/CONTEXT_DIR
# inside another project is re-derived). This file pins the 1023 shape as a
# whole, so a regression in either guard shows up as the reported failure.
# Contract kept: an explicit PROJECT_ROOT with no sentinel still wins (t4).

load ../test_helper

REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
FW="$REPO/bin/fw"

setup() {
    # OUTER plays 055 (the project the session came from), INNER plays 1023.
    OUTER="$(mktemp -d -t fw-t4879-outer-XXXXXX)"
    INNER="$(mktemp -d -t fw-t4879-inner-XXXXXX)"
    for p in "$OUTER" "$INNER"; do
        mkdir -p "$p/.tasks/active" "$p/.context/working"
        printf 'version: test\n' > "$p/.framework.yaml"
    done
    # OUTER's vendored framework copy: the FRAMEWORK_ROOT 1023 inherited.
    ln -s "$REPO" "$OUTER/.agentic-framework"
    NEUTRAL_HOME="$(mktemp -d -t fw-t4879-home-XXXXXX)"
}

teardown() {
    rm -rf "$OUTER" "$INNER" "$NEUTRAL_HOME"
}

_create() {
    bash "$FW" task create --name "t4879 probe" --type build --owner agent \
        --description "inherited-session probe"
}

@test "t1: full 1023 environment (supervised relaunch from OUTER) → task lands in INNER" {
    cd "$INNER"
    run env HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" FRAMEWORK_ROOT="$OUTER/.agentic-framework" \
        _FW_PATHS_DERIVED_BY="$OUTER" FW_ROUTED_FROM="$OUTER" FW_CLAUDE_FW_SUPERVISED=1 \
        CLAUDE_PROJECT_DIR="$OUTER" TASKS_DIR="$OUTER/.tasks" CONTEXT_DIR="$OUTER/.context" \
        bash -c "$(declare -f _create); FW='$FW' _create"
    [ "$status" -eq 0 ]
    ls "$INNER"/.tasks/active/T-*probe*.md
    [ -z "$(ls "$OUTER"/.tasks/active/)" ]
    # loud, not silent: the ignored value is named
    [[ "$output" == *"inherited PROJECT_ROOT=$OUTER is another project's"* ]]
}

@test "t2: the four variables unset, TASKS_DIR/CONTEXT_DIR still leaked (1023's second source) → INNER" {
    cd "$INNER"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM \
        HOME="$NEUTRAL_HOME" FW_CLAUDE_FW_SUPERVISED=1 CLAUDE_PROJECT_DIR="$OUTER" \
        TASKS_DIR="$OUTER/.tasks" CONTEXT_DIR="$OUTER/.context" \
        bash -c "$(declare -f _create); FW='$FW' _create"
    [ "$status" -eq 0 ]
    ls "$INNER"/.tasks/active/T-*probe*.md
    [ -z "$(ls "$OUTER"/.tasks/active/)" ]
    [[ "$output" == *"inherited TASKS_DIR=$OUTER/.tasks lies inside another project"* ]]
}

@test "t3: work-on under the 1023 environment sets focus in INNER, never OUTER" {
    cd "$INNER"
    run env HOME="$NEUTRAL_HOME" \
        PROJECT_ROOT="$OUTER" FRAMEWORK_ROOT="$OUTER/.agentic-framework" \
        _FW_PATHS_DERIVED_BY="$OUTER" FW_ROUTED_FROM="$OUTER" FW_CLAUDE_FW_SUPERVISED=1 \
        CLAUDE_PROJECT_DIR="$OUTER" TASKS_DIR="$OUTER/.tasks" CONTEXT_DIR="$OUTER/.context" \
        bash "$FW" work-on "t4879 focus probe" --type build
    [ "$status" -eq 0 ]
    grep -q '^current_task: T-' "$INNER/.context/working/focus.yaml"
    [ ! -f "$OUTER/.context/working/focus.yaml" ] || \
        ! grep -q '^current_task: T-' "$OUTER/.context/working/focus.yaml"
    [ -z "$(ls "$OUTER"/.tasks/active/)" ]
}

@test "t4: control — explicit PROJECT_ROOT with no sentinel still targets that project" {
    cd "$INNER"
    run env -u CLAUDE_PROJECT_DIR -u _FW_PATHS_DERIVED_BY -u TASKS_DIR -u CONTEXT_DIR \
        HOME="$NEUTRAL_HOME" PROJECT_ROOT="$OUTER" \
        bash -c "$(declare -f _create); FW='$FW' _create"
    [ "$status" -eq 0 ]
    ls "$OUTER"/.tasks/active/T-*probe*.md
    [ -z "$(ls "$INNER"/.tasks/active/)" ]
}
