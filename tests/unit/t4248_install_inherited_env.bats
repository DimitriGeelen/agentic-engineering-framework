#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4248: install.sh and bin/fw under a polluted inherited environment.
#
# Live symptom (dimitri-mint-dev, 2026-10-17): with FRAMEWORK_ROOT and PROJECT_ROOT
# leaked from another install, `fw init` sourced <target>/lib/init.sh ("No such
# file"), the installer reported "Installation complete!" with exit 0, and it
# overwrote ~/.local/bin/fw and claude-fw without backup or notice.
#
# Companion to install_target_project.bats (T-2809, with-target mode) and
# install_verify_no_cwd_init.bats (T-2799, no-target mode).

bats_require_minimum_version 1.5.0

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

setup() {
    TEST_HOME=$(mktemp -d)
    TEST_TARGET=$(mktemp -d)
    git init -q "$TEST_TARGET"
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
}

teardown() {
    rm -rf "$TEST_HOME" "$TEST_TARGET"
}

@test "T-4248: bin/fw re-resolves an inherited FRAMEWORK_ROOT that has no lib/ or agents/" {
    run env FRAMEWORK_ROOT="$TEST_TARGET" PROJECT_ROOT="$TEST_TARGET" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        bash "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TARGET" --provider generic
    [[ "$output" != *"No such file or directory"* ]]
    [[ "$output" == *"re-resolving"* ]]
    [ "$status" -eq 0 ]
    [ -f "$TEST_TARGET/.framework.yaml" ]
}

@test "T-4248: install.sh under an inherited polluted env reports success and initialises the target" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    run env -i HOME="$TEST_HOME" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        FRAMEWORK_ROOT="$TEST_TARGET" PROJECT_ROOT="$TEST_TARGET" \
        TASKS_DIR="$TEST_TARGET/.tasks" CONTEXT_DIR="$TEST_TARGET/.context" \
        _FW_PATHS_DERIVED_BY="$TEST_TARGET" FW_ROUTED_FROM="$TEST_TARGET" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        bash "$INSTALL" "$TEST_TARGET" --local "$FRAMEWORK_ROOT" --branch "$CURRENT_BRANCH" --no-scan
    [[ "$output" != *"No such file or directory"* ]]
    [[ "$output" != *"FAILED"* ]]
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installation complete!"* ]]
    [ -f "$TEST_TARGET/.framework.yaml" ]
    [ -f "$TEST_TARGET/.agentic-framework/FRAMEWORK.md" ]
}

@test "T-4248: install.sh backs up an existing ~/.local/bin/fw and claude-fw before replacing them" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi

    mkdir -p "$TEST_HOME/.local/bin"
    echo "OLD-FW-MARKER" > "$TEST_HOME/.local/bin/fw"
    echo "OLD-CLAUDE-FW-MARKER" > "$TEST_HOME/.local/bin/claude-fw"

    run env -i HOME="$TEST_HOME" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        bash "$INSTALL" "$TEST_TARGET" --local "$FRAMEWORK_ROOT" --branch "$CURRENT_BRANCH" --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backed up"* ]]

    local fw_bak claude_bak
    fw_bak=$(ls "$TEST_HOME/.local/bin/" | grep -E '^fw\.bak-' || true)
    claude_bak=$(ls "$TEST_HOME/.local/bin/" | grep -E '^claude-fw\.bak-' || true)
    [ -n "$fw_bak" ]
    [ -n "$claude_bak" ]
    grep -q "OLD-FW-MARKER" "$TEST_HOME/.local/bin/$fw_bak"
    grep -q "OLD-CLAUDE-FW-MARKER" "$TEST_HOME/.local/bin/$claude_bak"
}
