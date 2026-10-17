#!/usr/bin/env bats
# T-4251: when does `fw init <dir>` give <dir> its own git repo?
#
# Field symptom (dimitri-mint-dev run 3): a target with no .git sat under a repo
# rooted at /. The old test, `git rev-parse --is-inside-work-tree`, was true, so
# `git init` was skipped and hooks, task ids and the bootstrap commit landed in /.
#
# The rule (operator-delegated design): own repo when (1) the target is in no work
# tree, (2) the enclosing top-level is / or $HOME, or (3) install.sh created the
# directory itself (greenfield, FW_INIT_OWN_REPO=1). A genuine enclosing project
# repo (a monorepo package) is still attached to, with a notice.
#
# Companion to t4248_install_inherited_env.bats and install_target_project.bats.

bats_require_minimum_version 1.5.0

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL="$FRAMEWORK_ROOT/install.sh"

setup() {
    TEST_HOME=$(mktemp -d)
    OUTER=$(mktemp -d)
    OUTER=$(cd "$OUTER" && pwd -P)
    # Assertions here must see the same discovery boundary as the runs below.
    export GIT_CEILING_DIRECTORIES="$(dirname "$OUTER")"
    CURRENT_BRANCH="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
}

teardown() {
    rm -rf "$TEST_HOME" "$OUTER"
}

# An enclosing repo with a commit, so its HEAD can be compared afterwards.
make_outer_repo() {
    git init -q "$OUTER"
    git -C "$OUTER" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m "outer"
    OUTER_HEAD_BEFORE=$(git -C "$OUTER" rev-parse HEAD)
}

toplevel_of() {
    local top
    top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 0
    (cd "$top" && pwd -P)
}

# fw init under a clean env. $1 = HOME to use; GIT_CEILING_DIRECTORIES stops git
# discovery above $OUTER, so a host repo at / cannot leak into any case.
run_fw_init() {
    local home="$1" target="$2"
    run env -i HOME="$home" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        GIT_CEILING_DIRECTORIES="$(dirname "$OUTER")" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        bash "$FRAMEWORK_ROOT/bin/fw" init "$target" --provider generic
}

run_install() {
    run env -i HOME="$TEST_HOME" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        GIT_CEILING_DIRECTORIES="$(dirname "$OUTER")" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        bash "$INSTALL" "$1" --local "$FRAMEWORK_ROOT" --branch "$CURRENT_BRANCH" --no-scan
}

@test "T-4251 (1): fw init into a target in no work tree creates its own repo" {
    TARGET="$OUTER/proj"
    mkdir -p "$TARGET"
    [ -z "$(toplevel_of "$TARGET")" ]
    run_fw_init "$TEST_HOME" "$TARGET"
    [ "$(toplevel_of "$TARGET")" = "$OUTER/proj" ]
    [ ! -e "$OUTER/.git" ]
}

@test "T-4251 (2): enclosing repo at \$HOME gets no nested project: target gets its own repo, \$HOME repo untouched" {
    make_outer_repo
    TARGET="$OUTER/proj"
    mkdir -p "$TARGET"
    run_fw_init "$OUTER" "$TARGET"
    [ "$(toplevel_of "$TARGET")" = "$OUTER/proj" ]
    [ "$(git -C "$OUTER" rev-parse HEAD)" = "$OUTER_HEAD_BEFORE" ]
    [ ! -e "$OUTER/.git/hooks/pre-commit" ]
    [ ! -e "$OUTER/.tasks" ]
}

@test "T-4251: inside a genuine enclosing project repo fw init attaches, nests no repo, and says so" {
    make_outer_repo
    TARGET="$OUTER/packages/proj"
    mkdir -p "$TARGET"
    run_fw_init "$TEST_HOME" "$TARGET"
    [ "$(toplevel_of "$TARGET")" = "$OUTER" ]
    [ ! -e "$TARGET/.git" ]
    [[ "$output" == *"Attaching to the enclosing git repository at $OUTER"* ]]
    [[ "$output" == *"git init $TARGET"* ]]
}

# Two install.sh runs share one test: each is slow (fetch + vendor + doctor).
@test "T-4251 (3) + T-4248: install.sh greenfield under a project repo gets its own repo; a re-run is a no-op" {
    if [[ "$CURRENT_BRANCH" == "HEAD" ]]; then
        skip "detached HEAD -- --local install needs a real branch name"
    fi
    make_outer_repo
    TARGET="$OUTER/newproj"
    [ ! -e "$TARGET" ]
    run_install "$TARGET"
    echo "$output" | tail -40
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installation complete!"* ]]
    [ "$(toplevel_of "$TARGET")" = "$OUTER/newproj" ]
    [ "$(git -C "$OUTER" rev-parse HEAD)" = "$OUTER_HEAD_BEFORE" ]

    local before_yaml
    before_yaml="$(md5sum "$TARGET/.framework.yaml" | cut -d' ' -f1)"
    run_install "$TARGET"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project already initialised"* ]]
    [[ "$output" != *"FAILED"* ]]
    [ "$(md5sum "$TARGET/.framework.yaml" | cut -d' ' -f1)" = "$before_yaml" ]
}
