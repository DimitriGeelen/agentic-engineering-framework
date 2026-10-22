#!/usr/bin/env bats
# T-4661: `fw upgrade` run through a linked worktree's bin/fw pins THAT worktree.
#
# Field report (050, be.3): the operator checked out tag v1.8.15-be.3 as a git
# worktree and ran its bin/fw upgrade. The consumer's version_sha came back as
# the MAIN clone's HEAD (master), and the code synced was master's. Cause: the
# T-3111 authority redirect re-exec'd the main clone's bin/fw with FRAMEWORK_ROOT
# moved to the main clone, so upgrade's source was the clone, not the tag.
#
# The fixture is a real `git worktree add` of a real tag, with the main clone
# moved on past the tag afterwards — the only shape in which "the worktree's
# HEAD" and "the main clone's HEAD" are different answers. The fixture's
# lib/upgrade.sh is a stub that reports FRAMEWORK_ROOT and calls the REAL pin
# writer (lib/version-relation.sh:fw_record_version_sha) against a consumer
# .framework.yaml, so the asserted sha comes from the production writer.

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    [ -f "$_FW_ROOT/bin/fw" ] || skip "fw not found"

    TEST_ROOT="$(mktemp -d)"
    MAIN="$TEST_ROOT/main"
    WT="$TEST_ROOT/wt-tag"
    CONSUMER="$TEST_ROOT/consumer"

    mkdir -p "$MAIN/bin" "$MAIN/lib" "$MAIN/agents" "$MAIN/.context/working" "$MAIN/.tasks"
    echo "keep" > "$MAIN/.tasks/.keep"
    echo "keep" > "$MAIN/agents/.keep"
    echo "# fixture framework" > "$MAIN/FRAMEWORK.md"
    cp "$_FW_ROOT/bin/fw" "$MAIN/bin/fw"
    chmod +x "$MAIN/bin/fw"
    cp "$_FW_ROOT"/lib/*.sh "$_FW_ROOT"/lib/*.py "$MAIN/lib/" 2>/dev/null || true
    : > "$MAIN/lib/init.sh"
    cat > "$MAIN/lib/upgrade.sh" <<'STUB'
do_upgrade() {
    echo "UPGRADE-FRAMEWORK_ROOT=$FRAMEWORK_ROOT"
    source "$FRAMEWORK_ROOT/lib/version-relation.sh"
    fw_record_version_sha "$1/.framework.yaml" "$FRAMEWORK_ROOT"
}
STUB
    echo "1.0.0" > "$MAIN/VERSION"

    git -C "$MAIN" init -q
    git -C "$MAIN" config user.email t@t
    git -C "$MAIN" config user.name t
    git -C "$MAIN" add -A
    git -C "$MAIN" commit -qm "release"
    git -C "$MAIN" tag v1.0.0
    TAG_SHA=$(git -C "$MAIN" rev-parse v1.0.0)

    # The main clone moves on past the tag — the 050 shape (clone on master,
    # tag checked out beside it).
    echo "2.0.0-dev" > "$MAIN/VERSION"
    git -C "$MAIN" commit -qam "post-release work"
    MAIN_SHA=$(git -C "$MAIN" rev-parse HEAD)

    git -C "$MAIN" worktree add -q --detach "$WT" v1.0.0 >/dev/null 2>&1
    mkdir -p "$WT/.context/working"

    mkdir -p "$CONSUMER"
    printf 'project_name: consumer\nversion_sha: unset\n' > "$CONSUMER/.framework.yaml"
}

teardown() {
    [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

_clean() {
    env -u CLAUDE_PROJECT_DIR -u PROJECT_ROOT -u FRAMEWORK_ROOT \
        -u FW_REEXEC_DEPTH -u FW_NO_REEXEC "$@"
}

@test "fixture sanity: the tag and the main clone's HEAD differ" {
    [ "$TAG_SHA" != "$MAIN_SHA" ]
    [ "$(git -C "$WT" rev-parse HEAD)" = "$TAG_SHA" ]
}

@test "upgrade through the worktree's binary, run from the consumer, pins the TAG commit" {
    run _clean bash -c "cd '$CONSUMER' && '$WT/bin/fw' upgrade '$CONSUMER' 2>&1"
    [[ "$output" == *"UPGRADE-FRAMEWORK_ROOT=$WT"* ]]
    run grep "^version_sha:" "$CONSUMER/.framework.yaml"
    [ "$output" = "version_sha: $TAG_SHA" ]
}

@test "upgrade through the worktree's binary, run from inside the worktree, pins the TAG commit" {
    run _clean bash -c "cd '$WT' && ./bin/fw upgrade '$CONSUMER' 2>&1"
    [[ "$output" == *"UPGRADE-FRAMEWORK_ROOT=$WT"* ]]
    run grep "^version_sha:" "$CONSUMER/.framework.yaml"
    [ "$output" = "version_sha: $TAG_SHA" ]
}

@test "the main clone's binary still upgrades from the main clone (control)" {
    run _clean bash -c "cd '$CONSUMER' && '$MAIN/bin/fw' upgrade '$CONSUMER' 2>&1"
    [[ "$output" == *"UPGRADE-FRAMEWORK_ROOT=$MAIN"* ]]
    run grep "^version_sha:" "$CONSUMER/.framework.yaml"
    [ "$output" = "version_sha: $MAIN_SHA" ]
}

@test "other commands from the worktree still redirect to the authority (T-3111 kept)" {
    run _clean bash -c "cd '$WT' && ./bin/fw --version 2>&1"
    [[ "$output" == *"Framework: $MAIN"* ]]
}
