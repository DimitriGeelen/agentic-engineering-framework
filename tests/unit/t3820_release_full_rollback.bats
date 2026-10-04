#!/usr/bin/env bats
# T-3820: a refused publish rolled back master and the tag but left the
# VERSION-reconcile commit on the dev branch (v1.8.0 attempt 1: 1fa02d534 stayed
# on bleeding-edge, and the next ordinary push published VERSION=1.8.0 with no
# release behind it).
#
# The invariant pinned here: after ANY refused publish, HEAD, the VERSION bytes
# and the staged VERSION equal their pre-release state. Each refusal is paired
# with a control leg where the publish succeeds and the reconcile commit stays.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    ORIGIN="$TEST_TEMP_DIR/origin.git"
    REPO="$TEST_TEMP_DIR/repo"
    git init -q --bare -b master "$ORIGIN"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo 1.0.0 > "$REPO/VERSION"
    echo base > "$REPO/f"; git -C "$REPO" add f VERSION; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.0.0
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin master v1.0.0
    git -C "$REPO" checkout -q -b bleeding-edge
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm c2

    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"

    PRE_HEAD="$(git -C "$REPO" rev-parse HEAD)"
    PRE_MASTER="$(git -C "$REPO" rev-parse master)"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}
_sha()    { git -C "$REPO" rev-parse "$1" 2>/dev/null; }
_no_tag() { ! git -C "$REPO" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }

# The whole invariant, in one place: HEAD, bytes, index, master, tag.
_assert_pre_release_state() {
    local want_bytes="$1"
    [ "$(_sha HEAD)" = "$PRE_HEAD" ]
    [ "$(cat "$REPO/VERSION")" = "$want_bytes" ]
    [ "$(git -C "$REPO" show :VERSION)" = "$(git -C "$REPO" show "$PRE_HEAD:VERSION")" ]
    [ "$(_sha master)" = "$PRE_MASTER" ]
    _no_tag v1.0.1
}

# origin accepts the ancestry preflight but rejects the master update itself —
# what a server-side gate or a race produces after a clean preflight.
_origin_rejects_master() {
    cat > "$ORIGIN/hooks/update" <<'H'
#!/bin/sh
case "$1" in refs/heads/master) echo "remote: master refused" >&2; exit 1 ;; esac
exit 0
H
    chmod +x "$ORIGIN/hooks/update"
}

@test "premise: the release does make a reconcile commit on this fixture" {
    _release --dry-run
    [[ "$output" =~ would\ reconcile\ VERSION.*1\.0\.0\ →\ 1\.0\.1 ]]
}

@test "remote rejects master: the reconcile commit is reverted, HEAD and VERSION restored" {
    _origin_rejects_master
    _release
    [ "$status" -eq 1 ]
    [[ "$output" =~ "reached no remote" ]]
    _assert_pre_release_state 1.0.0
}

@test "remote rejects master: the rollback names the reverted reconcile commit" {
    _origin_rejects_master
    _release
    [[ "$output" =~ "Reverted the VERSION reconcile commit" ]]
}

@test "unreachable remote (--offline): full rollback" {
    git -C "$REPO" remote set-url origin "$TEST_TEMP_DIR/nonexistent.git"
    _release --offline
    [ "$status" -eq 1 ]
    _assert_pre_release_state 1.0.0
}

@test "local fast-forward fails (master held by a worktree): full rollback" {
    git -C "$REPO" worktree add -q "$TEST_TEMP_DIR/wt" master >/dev/null 2>&1
    _release
    [ "$status" -eq 1 ]
    _assert_pre_release_state 1.0.0
}

@test "tag creation fails: full rollback" {
    # A v1.0.1 tag on an unrelated commit: not reachable from HEAD, so
    # describe still answers v1.0.0, but `git tag -a v1.0.1` collides.
    git -C "$REPO" tag v1.0.1 "$(git -C "$REPO" commit-tree -m side "$(git -C "$REPO" write-tree)")"
    side="$(_sha v1.0.1)"
    _release
    [ "$status" -eq 1 ]
    [ "$(_sha HEAD)" = "$PRE_HEAD" ]
    [ "$(cat "$REPO/VERSION")" = "1.0.0" ]
    [ "$(_sha v1.0.1)" = "$side" ]
}

@test "the working-tree bytes are restored exactly, even when they differed from HEAD" {
    # A hook-stamped tree (T-3821): committed 1.0.0, working tree 1.0.0-stamp.
    printf '1.0.0\n\n' > "$REPO/VERSION"
    _origin_rejects_master
    _release
    [ "$status" -eq 1 ]
    [ "$(_sha HEAD)" = "$PRE_HEAD" ]
    [ "$(cat "$REPO/VERSION"; echo x)" = "$(printf '1.0.0\n\nx')" ]
}

@test "HEAD moved on after the reconcile: refuses to move HEAD, names the revert" {
    # Simulate a concurrent commit by making the remote push hook commit in REPO.
    cat > "$ORIGIN/hooks/update" <<H
#!/bin/sh
unset GIT_DIR GIT_QUARANTINE_PATH GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
git -C "$REPO" commit -q --allow-empty -m concurrent
exit 1
H
    chmod +x "$ORIGIN/hooks/update"
    _release
    [ "$status" -eq 1 ]
    [[ "$output" =~ "NOT reverted" ]]
    [[ "$output" =~ "git revert" ]]
    [ "$(git -C "$REPO" log -1 --format=%s)" = "concurrent" ]
}

@test "CONTROL: a successful publish KEEPS the reconcile commit" {
    _release
    [ "$status" -eq 0 ]
    [ "$(_sha HEAD)" != "$PRE_HEAD" ]
    [ "$(git -C "$REPO" show HEAD:VERSION)" = "1.0.1" ]
    [ "$(_sha v1.0.1^{commit})" = "$(_sha HEAD)" ]
    [ "$(git -C "$ORIGIN" rev-parse master)" = "$(_sha HEAD)" ]
}
