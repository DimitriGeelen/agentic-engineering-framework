#!/usr/bin/env bats
# T-3819: the release preflight graded fast-forwardability against the LOCAL
# release-branch ref only. v1.8.0 attempt 1: origin/master held eb49ff9 (a
# peer's direct commit) that the local master did not; preflight said "clean",
# the release committed VERSION and tagged, and only the push found out.
#
# Fixture: a bare "origin" plus a clone; origin's master gets a commit the clone
# lacks. Every refusal is paired with a control leg over the same fixture.
# Negations go through _no_* helpers (`! cmd` is inert in bats, see t3190).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    ORIGIN="$TEST_TEMP_DIR/origin.git"
    REPO="$TEST_TEMP_DIR/repo"
    PEER="$TEST_TEMP_DIR/peer"
    git init -q --bare -b master "$ORIGIN"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo base > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.0.0
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin master v1.0.0
    git -C "$REPO" checkout -q -b bleeding-edge
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm c2

    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

# A peer commits straight to origin/master: the clone's local master never sees it.
_peer_commits_to_origin_master() {
    git clone -q "$ORIGIN" "$PEER"
    git -C "$PEER" config user.email p@p.p; git -C "$PEER" config user.name p
    echo foreign > "$PEER/ring20"; git -C "$PEER" add ring20
    git -C "$PEER" commit -qm "foreign: ring20 direct commit"
    git -C "$PEER" push -q origin master
}

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}
_sha()    { git -C "$REPO" rev-parse "$1" 2>/dev/null; }
_no_tag() { ! git -C "$REPO" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }
_has_tag() { git -C "$REPO" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }

@test "premise: the LOCAL verdict alone is 'clean' on this fixture" {
    _peer_commits_to_origin_master
    run bash -c "source '$LIB'; release_ff_state '$REPO' master"
    [ "$output" = "clean" ]
}

@test "REFUSES when origin/master holds a commit HEAD lacks" {
    _peer_commits_to_origin_master
    _release
    [ "$status" -eq 1 ]
    [[ "$output" =~ "REFUSING to release" ]]
    [[ "$output" =~ "origin/master" ]]
}

@test "the refusal names the foreign commit and the merge instruction" {
    _peer_commits_to_origin_master
    _release
    [[ "$output" =~ "foreign: ring20 direct commit" ]]
    [[ "$output" =~ "merge origin/master into your dev branch first" ]]
}

@test "the refusal writes nothing: no tag, HEAD and local master unchanged" {
    _peer_commits_to_origin_master
    head_before="$(_sha HEAD)"; master_before="$(_sha master)"
    _release
    _no_tag v1.0.1
    [ "$(_sha HEAD)" = "$head_before" ]
    [ "$(_sha master)" = "$master_before" ]
}

@test "the refusal fires BEFORE the VERSION reconcile commit" {
    echo 1.0.0 > "$REPO/VERSION"; git -C "$REPO" add VERSION; git -C "$REPO" commit -qm ver
    _peer_commits_to_origin_master
    head_before="$(_sha HEAD)"
    _release
    [ "$status" -eq 1 ]
    [ "$(_sha HEAD)" = "$head_before" ]
    [ "$(cat "$REPO/VERSION")" = "1.0.0" ]
}

@test "--dry-run runs the same remote check and refuses" {
    _peer_commits_to_origin_master
    _release --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" =~ "merge origin/master into your dev branch first" ]]
    _no_tag v1.0.1
}

@test "CONTROL: once origin/master is merged in, the same fixture releases" {
    _peer_commits_to_origin_master
    git -C "$REPO" fetch -q origin master
    git -C "$REPO" merge -q --no-edit origin/master
    _release
    [ "$status" -eq 0 ]
    _has_tag v1.0.1
    [ "$(git -C "$ORIGIN" rev-parse master)" = "$(_sha bleeding-edge)" ]
}

@test "CONTROL: an origin that is merely behind passes and is reported" {
    _release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ancestor of HEAD" ]]
}

@test "unreachable remote REFUSES without --offline, and says so" {
    git -C "$REPO" remote set-url origin "$TEST_TEMP_DIR/nonexistent.git"
    _release --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" =~ "cannot reach remote 'origin'" ]]
    [[ "$output" =~ "--offline" ]]
}

@test "--offline skips the remote check and says it was skipped" {
    git -C "$REPO" remote set-url origin "$TEST_TEMP_DIR/nonexistent.git"
    _release --dry-run --offline
    [ "$status" -eq 0 ]
    [[ "$output" =~ "remote fast-forward check SKIPPED" ]]
}

@test "no remotes: the check is skipped explicitly, not silently" {
    git -C "$REPO" remote remove origin
    _release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No remotes configured" ]]
}

@test "remote lacking the release branch passes (the push creates it)" {
    git -C "$ORIGIN" update-ref -d refs/heads/master
    _release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "has no 'master' yet" ]]
}
