#!/usr/bin/env bats
# T-3190 / G-096: the release train had no engine.
#
# CLAUDE.md §Release-Train Branch Model says a release "cuts the tag and
# fast-forwards master". lib/release.sh contained zero references to master:
# it tagged HEAD, pushed the tag, exited 0, and never touched the install
# surface. Every observable signal reported a successful release.
#
# That is the false-green shape T-3187 closed on the branch guard, in a second
# place: the command answers a question adjacent to the one it appears to
# answer. So the discipline is the same here — a test asserting that something
# does NOT happen is worthless alone, because "correctly quiet" and "never
# looked" are the same output. Every silent assertion below is paired with a
# firing one over the same fixture.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    echo base > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm "c1"
    git -C "$REPO" tag v1.0.0
    # The release-train shape: master is the install surface, bleeding-edge is
    # ahead of it by real work. This is a CLEAN fast-forward.
    git -C "$REPO" checkout -q -b bleeding-edge
    echo dev > "$REPO/f2"; git -C "$REPO" add f2; git -C "$REPO" commit -qm "c2"

    # Stub gh so the best-effort GitHub Release leg never reaches the network.
    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"

    LIB="$FRAMEWORK_ROOT/lib/release.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}

_sha()      { git -C "$REPO" rev-parse "$1" 2>/dev/null; }
_has_tag()  { git -C "$REPO" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }
# _no_tag exists because `! _has_tag X` is INERT in bats: POSIX `set -e`
# explicitly exempts any command preceded by `!`, so a failing negation is
# swallowed and the test reports green without having asserted anything.
# Caught by mutation testing (removing the tag rollback reddened nothing).
# Keeping the `!` inside the function makes the caller a bare command again,
# which `set -e` does abort on.
_no_tag()   { ! git -C "$REPO" rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1; }

# ── The engine itself ────────────────────────────────────────────────────

@test "a release fast-forwards the release branch to HEAD" {
    [ "$(_sha master)" != "$(_sha HEAD)" ]   # precondition: it is genuinely behind
    _release
    [ "$status" -eq 0 ]
    [ "$(_sha master)" = "$(_sha bleeding-edge)" ]
}

@test "the release still cuts its tag" {
    _release
    [ "$status" -eq 0 ]
    _has_tag v1.0.1
}

@test "the fast-forward is reported, not silent" {
    _release
    [[ "$output" =~ "Fast-forwarding master" ]]
}

# ── Refusals: the half the old code reported as success ──────────────────

@test "REFUSES when the release branch is AHEAD of HEAD" {
    git -C "$REPO" checkout -q master
    git -C "$REPO" merge -q --ff-only bleeding-edge
    echo later > "$REPO/f3"; git -C "$REPO" add f3; git -C "$REPO" commit -qm "c3"
    git -C "$REPO" checkout -q bleeding-edge
    _release
    [ "$status" -eq 1 ]
    [[ "$output" =~ "REFUSING to release" ]]
    [[ "$output" =~ "AHEAD" ]]
}

@test "the AHEAD refusal leaves NO tag behind" {
    git -C "$REPO" checkout -q master
    git -C "$REPO" merge -q --ff-only bleeding-edge
    echo later > "$REPO/f3"; git -C "$REPO" add f3; git -C "$REPO" commit -qm "c3"
    git -C "$REPO" checkout -q bleeding-edge
    _release
    _no_tag v1.0.1
}

@test "REFUSES when the branches have DIVERGED" {
    git -C "$REPO" checkout -q master
    echo other > "$REPO/f4"; git -C "$REPO" add f4; git -C "$REPO" commit -qm "c2m"
    git -C "$REPO" checkout -q bleeding-edge
    _release
    [ "$status" -eq 1 ]
    [[ "$output" =~ "DIVERGED" ]]
}

@test "the DIVERGED refusal leaves NO tag behind" {
    git -C "$REPO" checkout -q master
    echo other > "$REPO/f4"; git -C "$REPO" add f4; git -C "$REPO" commit -qm "c2m"
    git -C "$REPO" checkout -q bleeding-edge
    _release
    _no_tag v1.0.1
}

@test "CONTROL LEG: an up-to-date release branch does NOT refuse" {
    # Pairs with both refusals above. Without it, 'refuses on divergence' and
    # 'refuses on everything' are the same implementation.
    git -C "$REPO" branch -f master HEAD
    _release
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "REFUSING" ]]
    _has_tag v1.0.1
}

# ── Dry run must be inert ────────────────────────────────────────────────

@test "--dry-run reports the fast-forward it would perform" {
    _release --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "would fast-forward master" ]]
}

@test "--dry-run moves nothing and publishes nothing" {
    before="$(_sha master)"
    _release --dry-run
    [ "$(_sha master)" = "$before" ]
    _no_tag v1.0.1
}

@test "CONTROL LEG: the same fixture DOES move without --dry-run" {
    # Proves the assertion above measured dry-run's restraint, not a fixture
    # that could never have moved in the first place.
    before="$(_sha master)"
    _release
    [ "$(_sha master)" != "$before" ]
    _has_tag v1.0.1
}

# ── Scope: do not cry outside the model ──────────────────────────────────

@test "SCOPE: a repo with no release branch releases without refusing" {
    git -C "$REPO" branch -q -D master
    _release
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "REFUSING" ]]
    _has_tag v1.0.1
}

@test "SCOPE: the missing branch is announced, not swallowed" {
    git -C "$REPO" branch -q -D master
    _release
    [[ "$output" =~ "skipping the fast-forward" ]]
}

@test "FW_RELEASE_BRANCH overrides which branch is advanced" {
    git -C "$REPO" branch -q -D master
    git -C "$REPO" branch -q stable v1.0.0
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" FW_RELEASE_BRANCH=stable \
        bash -c "source '$LIB'; release_tag_and_release" 2>&1
    [ "$status" -eq 0 ]
    [ "$(_sha stable)" = "$(_sha bleeding-edge)" ]
}

# ── Ordering: the advance precedes publication ───────────────────────────

@test "ORDERING: no tag survives when the fast-forward cannot be performed" {
    # master checked out in a linked worktree => `git branch -f` must fail.
    # The tag is created before this point, so this pins the rollback.
    git -C "$REPO" worktree add -q "$TEST_TEMP_DIR/wt" master >/dev/null 2>&1
    _release
    [ "$status" -eq 1 ]
    _no_tag v1.0.1
    [[ "$output" =~ "nothing was published" ]]
}

# ── The local advance is not the release: the remote must receive it ─────

@test "REFUSES to publish when the release branch reaches no remote" {
    git -C "$REPO" remote add broken "$TEST_TEMP_DIR/nonexistent.git"
    _release
    [ "$status" -eq 1 ]
    [[ "$output" =~ "reached no remote" ]]
    _no_tag v1.0.1
}

@test "the failed publish ROLLS BACK the local branch too" {
    before="$(_sha master)"
    git -C "$REPO" remote add broken "$TEST_TEMP_DIR/nonexistent.git"
    _release
    [ "$(_sha master)" = "$before" ]
}

@test "CONTROL LEG: a reachable remote publishes normally" {
    # Pairs with both tests above: proves they measured an unreachable remote,
    # not merely the presence of any remote at all.
    git -C "$REPO" init -q --bare "$TEST_TEMP_DIR/upstream.git"
    git -C "$REPO" remote add origin "$TEST_TEMP_DIR/upstream.git"
    _release
    [ "$status" -eq 0 ]
    [ "$(_sha master)" = "$(_sha bleeding-edge)" ]
    _has_tag v1.0.1
    [ "$(git -C "$TEST_TEMP_DIR/upstream.git" rev-parse master)" = "$(_sha bleeding-edge)" ]
}
