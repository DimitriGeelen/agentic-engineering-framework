#!/usr/bin/env bats
# T-3821: VERSION had two writers that disagreed.
#   - the pre-push hook stamped the working tree as <major.minor>.<commits>
#     (agents/git/lib/hooks.sh, T-648) on every push;
#   - fw release reconciled it to the tag (T-3242).
# After any push the tree disagreed with the commit. v1.8.0 attempt 2: VERSION
# 1.8.0 was already committed, the stamp rewrote the tree to 1.7.N, the release
# "reconciled" back to 1.8.0, the commit came out empty, and the release refused.
#
# Decision: both legs. The hook no longer writes a TRACKED VERSION, and the
# release grades committed content and treats "already equal" as success.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo 1.0.0 > "$REPO/VERSION"
    echo base > "$REPO/f"; git -C "$REPO" add f VERSION; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.0.0
    git -C "$REPO" checkout -q -b bleeding-edge
    for i in 1 2 3; do echo "$i" > "$REPO/w$i"; git -C "$REPO" add "w$i"; git -C "$REPO" commit -qm "w$i"; done

    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/gh"; chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
    HOOKS="$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

_release() {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_tag_and_release $*" 2>&1
}
_sha() { git -C "$REPO" rev-parse "$1" 2>/dev/null; }

# Run the hook's stamp block exactly as shipped (extracted from the heredoc).
_run_stamp_block() {
    sed -n '/^# Stamp VERSION file from git describe/,/^    echo "VERSION stamped: \$_stamped"/p' "$HOOKS" > "$TEST_TEMP_DIR/stamp.sh"
    echo fi >> "$TEST_TEMP_DIR/stamp.sh"
    run bash -c "cd '$REPO' && PROJECT_ROOT='$REPO' bash '$TEST_TEMP_DIR/stamp.sh'" 2>&1
}

# ── release leg ───────────────────────────────────────────────────────────

@test "a hook-stamped working tree does not derail the release" {
    echo 1.0.3 > "$REPO/VERSION"     # what the old hook writes: 1.0.<3 commits>
    _release --bump minor
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" show v1.1.0:VERSION)" = "1.1.0" ]
}

@test "a stamp ABOVE the patch bump is not a false DECREASE (graded on HEAD's content)" {
    echo 1.0.3 > "$REPO/VERSION"     # stamp 1.0.3 > next patch 1.0.1
    _release
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "DECREASE" ]]
    [ "$(git -C "$REPO" show v1.0.1:VERSION)" = "1.0.1" ]
}

@test "CONTROL: a COMMITTED VERSION above the tag still refuses as a DECREASE" {
    echo 2.0.0 > "$REPO/VERSION"; git -C "$REPO" commit -qam "ahead"
    _release
    [ "$status" -eq 1 ]
    [[ "$output" =~ "DECREASE" ]]
}

@test "attempt-2 shape: VERSION already committed at the release version + stamped tree -> no empty commit, success" {
    echo 1.0.1 > "$REPO/VERSION"; git -C "$REPO" commit -qam "pre-committed 1.0.1"
    before="$(_sha HEAD)"
    echo 1.0.4 > "$REPO/VERSION"     # the hook re-stamps after a push
    _release
    [ "$status" -eq 0 ]
    [ "$(_sha HEAD)" = "$before" ]          # no new (empty or otherwise) commit
    [ "$(_sha 'v1.0.1^{commit}')" = "$before" ]
    [[ ! "$output" =~ "reconciliation commit failed" ]]
}

@test "release_reconcile_version: equal to HEAD's content returns 0 without committing" {
    echo 1.0.1 > "$REPO/VERSION"; git -C "$REPO" commit -qam "pre"
    before="$(_sha HEAD)"
    echo 9.9.9 > "$REPO/VERSION"
    run bash -c "source '$LIB'; release_reconcile_version '$REPO' v1.0.1"
    [ "$status" -eq 0 ]
    [ "$(_sha HEAD)" = "$before" ]
    [ "$(cat "$REPO/VERSION")" = "1.0.1" ]
}

@test "CONTROL: release_reconcile_version still commits a real change" {
    before="$(_sha HEAD)"
    run bash -c "source '$LIB'; release_reconcile_version '$REPO' v1.0.1"
    [ "$status" -eq 0 ]
    [ "$(_sha HEAD)" != "$before" ]
    [ "$(git -C "$REPO" show HEAD:VERSION)" = "1.0.1" ]
}

@test "a stale vendored copy beside a current root VERSION is still reconciled" {
    mkdir -p "$REPO/.agentic-framework"
    echo 0.9.0 > "$REPO/.agentic-framework/VERSION"
    echo 1.0.1 > "$REPO/VERSION"
    git -C "$REPO" add VERSION .agentic-framework/VERSION; git -C "$REPO" commit -qm "root current, vendored stale"
    _release
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" show v1.0.1:.agentic-framework/VERSION)" = "1.0.1" ]
}

# ── hook leg ──────────────────────────────────────────────────────────────

@test "hook: a TRACKED VERSION is not stamped, and the hook says so" {
    _run_stamp_block
    [ "$status" -eq 0 ]
    [[ "$output" =~ "not stamped" ]]
    [ "$(cat "$REPO/VERSION")" = "1.0.0" ]
}

@test "CONTROL hook: an UNTRACKED VERSION is still stamped from git describe (T-648)" {
    git -C "$REPO" rm -q --cached VERSION; git -C "$REPO" commit -qm "untrack VERSION"
    _run_stamp_block
    [ "$status" -eq 0 ]
    [[ "$output" =~ "VERSION stamped: 1.0.4" ]]
    [ "$(cat "$REPO/VERSION")" = "1.0.4" ]
}
