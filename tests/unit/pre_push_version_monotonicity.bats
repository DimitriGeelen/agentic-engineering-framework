#!/usr/bin/env bats
# T-1603: VERSION monotonicity gate — pre-push hook tests
# Origin: T-1602 surfaced silent VERSION rollback in cc38e98f5 (1.5.463 → 1.5.19)
# unchecked by any structural gate. This test pins the gate.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INSTALL_HOOKS="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TMP_REPO="$(mktemp -d)"
    cd "$TMP_REPO"
    git init -q
    git config user.email "test@local"
    git config user.name "test"
    git config commit.gpgsign false
    # Stub audit so the hook's audit step doesn't fail in the temp repo
    mkdir -p agents/audit
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x agents/audit/audit.sh
    # Copy the framework's installed pre-push hook directly — this is the same
    # content `fw git install-hooks` would install. We avoid re-running the
    # installer here because it depends on framework lib/paths.sh resolution.
    mkdir -p .git/hooks
    cp "$FRAMEWORK_ROOT/.git/hooks/pre-push" .git/hooks/pre-push
    chmod +x .git/hooks/pre-push
    # Initial commit + VERSION
    echo "1.0.0" > VERSION
    git add VERSION agents/audit/audit.sh
    git commit -q -m "T-0: init VERSION 1.0.0"
    [ -f .git/hooks/pre-push ]
}

teardown() {
    cd /
    rm -rf "$TMP_REPO"
}

# --- Source-level marker ---

@test "pre-push hook contains VERSION monotonicity marker" {
    run grep -q "VERSION monotonicity" .git/hooks/pre-push
    [ "$status" -eq 0 ]
}

# --- Behavior tests ---

@test "pre-push allows VERSION bump (1.0.0 → 1.1.0)" {
    REMOTE_SHA="$(git rev-parse HEAD)"
    echo "1.1.0" > VERSION
    git add VERSION
    git -c commit.gpgsign=false commit -q -m "T-0: bump 1.1.0"
    LOCAL_SHA="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
}

@test "pre-push allows equal VERSION (no change)" {
    REMOTE_SHA="$(git rev-parse HEAD)"
    echo "irrelevant change" > README.md
    git add README.md
    git -c commit.gpgsign=false commit -q -m "T-0: docs only"
    LOCAL_SHA="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -eq 0 ]
}

@test "pre-push BLOCKS VERSION rollback (1.0.0 → 0.9.0)" {
    REMOTE_SHA="$(git rev-parse HEAD)"
    echo "0.9.0" > VERSION
    git add VERSION
    git -c commit.gpgsign=false commit -q -m "T-0: rollback (intentional in test)"
    LOCAL_SHA="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -ne 0 ]
    [[ "$output" == *"VERSION monotonicity violation"* ]]
}

@test "pre-push BLOCKS the cc38e98f5 case (1.5.463 → 1.5.19)" {
    # Pin the original incident shape: 444-version drop.
    echo "1.5.463" > VERSION
    git add VERSION
    git -c commit.gpgsign=false commit -q -m "T-0: at 1.5.463"
    REMOTE_SHA="$(git rev-parse HEAD)"
    echo "1.5.19" > VERSION
    git add VERSION
    git -c commit.gpgsign=false commit -q -m "T-0: cc38e98f5 shape"
    LOCAL_SHA="$(git rev-parse HEAD)"
    run bash -c "echo 'refs/heads/master $LOCAL_SHA refs/heads/master $REMOTE_SHA' | .git/hooks/pre-push origin http://localhost"
    [ "$status" -ne 0 ]
    [[ "$output" == *"1.5.19"* ]]
    [[ "$output" == *"1.5.463"* ]]
}

@test "pre-push ignores non-branch refs (tag pushes pass through)" {
    REMOTE_SHA="$(git rev-parse HEAD)"
    echo "0.9.0" > VERSION
    git add VERSION
    git -c commit.gpgsign=false commit -q -m "T-0: 0.9.0"
    LOCAL_SHA="$(git rev-parse HEAD)"
    git tag -a v0.9.0 -m "test tag"
    TAG_SHA="$(git rev-parse v0.9.0)"
    # Pushing only the tag: VERSION check should not fire (not a refs/heads/*)
    # Lightweight-tag check would fire if it were lightweight; this is annotated.
    run bash -c "echo 'refs/tags/v0.9.0 $TAG_SHA refs/tags/v0.9.0 0000000000000000000000000000000000000000' | .git/hooks/pre-push origin http://localhost"
    # Should NOT block on VERSION (we only push the tag); audit may still pass
    [[ "$output" != *"VERSION monotonicity"* ]]
}
