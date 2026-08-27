#!/usr/bin/env bats
# T-3193: a release that cannot publish its tag must not report success.
#
# T-3190 guarded one direction — no tag survives publication if the release
# branch cannot advance. The first real release hit the mirror image:
#
#   1. the release-branch push to origin SUCCEEDED
#   2. the pre-push audit lock (held by the daily cron) then blocked the TAG push
#   3. release_tag_and_release carried on and created a GitHub Release for a tag
#      origin does not have
#
# Consumers then see the install surface at the new commit, nothing naming it,
# and a GitHub Release page asserting the release shipped. The command did
# return non-zero, but `fw release … | tail` reads the pipeline's 0.
#
# ── on the shape of these tests ──────────────────────────────────────────
# Every "X did not happen" assertion is paired with a fixture where X DOES
# happen, over the same code path. Without the pair, "correctly refused" and
# "never got that far" are the same observation — and this whole task exists
# because a release reported success while doing nothing of the kind.
#
# `! cmd` is INERT in bats (POSIX exempts `set -e` for any command preceded by
# `!`, and bats reads only the last command's status). t3190 found this
# independently and solved it with a wrapper; t100195 carried five inert
# assertions for months because the knowledge lived one file over. Negations
# here go through _no_* helpers, which make the caller a bare command that
# `set -e` does abort on. Lint tracked in T-3191.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    ORIGIN="$TEST_TEMP_DIR/origin.git"

    git init -q --bare -b master "$ORIGIN"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo base > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.0.0
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin master
    git -C "$REPO" push -q origin v1.0.0

    # release-train shape: master is the install surface, bleeding-edge is ahead
    git -C "$REPO" checkout -q -b bleeding-edge
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm c2

    # gh stub that RECORDS being called, so "no GitHub Release" is a fact we
    # observe rather than an absence we assume.
    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    GH_MARKER="$TEST_TEMP_DIR/gh-release-created"
    cat > "$STUB_BIN/gh" <<EOF
#!/bin/sh
if [ "\$1" = "release" ] && [ "\$2" = "create" ]; then
    echo "\$3" > "$GH_MARKER"
fi
exit 0
EOF
    chmod +x "$STUB_BIN/gh"

    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

# Make origin reject every tag ref while still accepting branch refs — the
# exact asymmetry a pre-push audit gate produces.
_reject_tags_on_origin() {
    cat > "$ORIGIN/hooks/update" <<'EOF'
#!/bin/sh
case "$1" in
    refs/tags/*) echo "remote: tag push refused (simulating the audit lock)" >&2; exit 1 ;;
esac
exit 0
EOF
    chmod +x "$ORIGIN/hooks/update"
}

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}

_remote_sha()      { git -C "$ORIGIN" rev-parse "$1" 2>/dev/null; }
_local_sha()       { git -C "$REPO" rev-parse "$1" 2>/dev/null; }
_gh_called()       { [ -f "$GH_MARKER" ]; }
_gh_not_called()   { [ ! -f "$GH_MARKER" ]; }
_remote_has_tag()  { git -C "$ORIGIN" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }
_remote_no_tag()   { ! git -C "$ORIGIN" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }
_local_has_tag()   { git -C "$REPO" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }

# ── CONTROL LEG (AC6) ─────────────────────────────────────────────────────
# Everything below asserts a refusal. This asserts the feature works when
# nothing is broken, so a refusal test cannot pass by the code never running.

@test "CONTROL: branch push and tag push both succeed -> GitHub Release, exit 0" {
    _release
    [ "$status" -eq 0 ]
    _remote_has_tag v1.0.1
    [ "$(_remote_sha master)" = "$(_local_sha bleeding-edge)" ]
    _gh_called
    [ "$(cat "$GH_MARKER")" = "v1.0.1" ]
}

# ── THE DEFECT (AC1, AC5) ─────────────────────────────────────────────────

@test "tag push fails -> no GitHub Release is created" {
    _reject_tags_on_origin
    _release
    _gh_not_called
}

@test "tag push fails -> the command exits non-zero" {
    _reject_tags_on_origin
    _release
    [ "$status" -ne 0 ]
}

@test "tag push fails -> the refusal is explicit, not a warning buried in output" {
    _reject_tags_on_origin
    _release
    [[ "$output" =~ "REFUSING to publish" ]]
    [[ "$output" =~ "reached no remote" ]]
}

@test "the tag genuinely did not reach the remote — the premise, asserted" {
    # Without this the suite could pass against a build where the tag pushed
    # fine and something else refused: "refused correctly" and "refused for an
    # unrelated reason" would be indistinguishable.
    _reject_tags_on_origin
    _release
    _remote_no_tag v1.0.1
}

# ── AC3: which invariant wins ─────────────────────────────────────────────

@test "the already-pushed release branch is NOT rolled back" {
    # The branch-push guard CAN roll back, because it fires when the branch
    # reached no remote — nothing published, nothing to retract. Here master IS
    # published and consumers may have fetched it, so retracting means a force
    # push to the install surface. The release is held open instead.
    _reject_tags_on_origin
    _release
    [ "$(_remote_sha master)" = "$(_local_sha bleeding-edge)" ]
}

@test "the local tag is KEPT so the release can be resumed" {
    _reject_tags_on_origin
    _release
    _local_has_tag v1.0.1
}

@test "the refusal names the resume path and the reason master stands" {
    _reject_tags_on_origin
    _release
    [[ "$output" =~ "release tag-and-release" ]]
    [[ "$output" =~ "not being rolled back" ]]
}

# ── AC2: retry rather than fail on first contention ───────────────────────

@test "the tag push is retried before the release is refused" {
    # The observed cause was our own audit lock, held by cron — the common
    # case. Failing a release on first contention turns a two-minute wait into
    # a half-published release.
    _reject_tags_on_origin
    _release
    [[ "$output" =~ "retry 1/3" ]]
    [[ "$output" =~ "retry 2/3" ]]
}

@test "CONTROL: a healthy tag push does NOT retry" {
    # Pairs with the above: proves the retry text is produced by failure, not
    # printed unconditionally on every release.
    _release
    [ "$status" -eq 0 ]
    if echo "$output" | grep -q "retry 1/3"; then false; fi
}
