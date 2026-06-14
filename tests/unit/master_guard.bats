#!/usr/bin/env bats
# Unit tests for agents/git/lib/master-guard.sh (T-2396, inception T-2394 G1)
#
# The guard refuses a DIRECT authored commit when HEAD is on master/main, while
# allowing merges, rebases, fast-forwards (no commit fires the hook), feature
# branches, protection-off, and the two documented bypasses. Each test runs the
# guard CLI (`master-guard.sh check`) against a real throwaway git repo so the
# branch / MERGE_HEAD / rebase-dir detection exercises real `git` plumbing — not
# mocks (the bug class L-399 warns about lives at the git join, not in isolation).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    git init -q -b master "$REPO"
    cd "$REPO"
    git config user.email "test@test"
    git config user.name "test"
    git commit --allow-empty -q -m "init"
    GUARD="$FRAMEWORK_ROOT/agents/git/lib/master-guard.sh"
    export PROJECT_ROOT="$REPO"   # temp repo has no .framework.yaml → FW_PROTECT_MASTER env decides
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- block-direct: the core invariant ---

@test "block-direct: enabled + on master + no merge/rebase → BLOCK (exit 1)" {
    run env PROJECT_ROOT="$REPO" FW_PROTECT_MASTER=1 bash "$GUARD" check
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"master"* ]]
}

@test "block-direct: also guards 'main' branch (exit 1)" {
    git checkout -q -b main
    run env PROJECT_ROOT="$REPO" FW_PROTECT_MASTER=1 bash "$GUARD" check
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"main"* ]]
}

# --- block message names BOTH bypass mechanisms + the branch→merge flow (AC#4, L-399 parity) ---

@test "block-message: names FW_ALLOW_MASTER_COMMIT, --no-verify, and the branch→merge flow" {
    run env PROJECT_ROOT="$REPO" FW_PROTECT_MASTER=1 bash "$GUARD" check
    [ "$status" -eq 1 ]
    [[ "$output" == *"FW_ALLOW_MASTER_COMMIT=1"* ]]
    [[ "$output" == *"--no-verify"* ]]
    [[ "$output" == *"switch -c"* ]]
}

# --- allow-merge: a merge commit on master is a legitimate advance ---

@test "allow-merge: enabled + on master + MERGE_HEAD present → allow (exit 0)" {
    echo "$(git rev-parse HEAD)" > "$(git rev-parse --git-path MERGE_HEAD)"
    run env PROJECT_ROOT="$REPO" FW_PROTECT_MASTER=1 bash "$GUARD" check
    [ "$status" -eq 0 ]
}

# --- allow-rebase: a rebase replays commits onto master legitimately ---

@test "allow-rebase: enabled + on master + rebase-merge dir present → allow (exit 0)" {
    mkdir -p "$(git rev-parse --git-path rebase-merge)"
    run env PROJECT_ROOT="$REPO" FW_PROTECT_MASTER=1 bash "$GUARD" check
    [ "$status" -eq 0 ]
}

@test "allow-rebase: enabled + on master + rebase-apply dir present → allow (exit 0)" {
    mkdir -p "$(git rev-parse --git-path rebase-apply)"
    run env PROJECT_ROOT="$REPO" FW_PROTECT_MASTER=1 bash "$GUARD" check
    [ "$status" -eq 0 ]
}

# --- allow-feature-branch: only master/main are guarded ---

@test "allow-feature-branch: enabled + on a feature branch → allow (exit 0)" {
    git checkout -q -b feature/x
    run env PROJECT_ROOT="$REPO" FW_PROTECT_MASTER=1 bash "$GUARD" check
    [ "$status" -eq 0 ]
}

# --- file-based arming: PROTECT_MASTER in .framework.yaml (UPPERCASE) is read ---
# Regression guard: a lowercase `protect_master:` key would never be read by
# fw_config (it greps `^PROTECT_MASTER:` verbatim) → guard silently OFF. This
# test pins the file-read path AND the correct key case end-to-end.

@test "file-arming: PROTECT_MASTER:1 in .framework.yaml + on master → BLOCK (exit 1)" {
    # Make the temp repo resolve config: point framework_path at the real
    # framework so fw_config/config.sh is sourceable, and set the key here.
    printf 'framework_path: %s\nPROTECT_MASTER: 1\n' "$FRAMEWORK_ROOT" > "$REPO/.framework.yaml"
    run env PROJECT_ROOT="$REPO" bash "$GUARD" check   # no FW_PROTECT_MASTER env → file must decide
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED"* ]]
}

@test "file-arming: lowercase protect_master:1 is NOT read → guard stays OFF (exit 0)" {
    # Proves the case-sensitivity: lowercase key is inert (the bug this guards against).
    printf 'framework_path: %s\nprotect_master: 1\n' "$FRAMEWORK_ROOT" > "$REPO/.framework.yaml"
    run env PROJECT_ROOT="$REPO" bash "$GUARD" check
    [ "$status" -eq 0 ]
}

# --- off-by-default: consumer-safe — no protection unless opted in ---

@test "off-by-default: protection unset + on master → allow (exit 0)" {
    # No FW_PROTECT_MASTER, no .framework.yaml in the temp repo → guard is inert.
    run env PROJECT_ROOT="$REPO" bash "$GUARD" check
    [ "$status" -eq 0 ]
}

# --- env-bypass: explicit Tier-2 override allows but WARNs ---

@test "env-bypass: enabled + FW_ALLOW_MASTER_COMMIT=1 on master → allow (exit 0) + WARN" {
    run env PROJECT_ROOT="$REPO" FW_PROTECT_MASTER=1 FW_ALLOW_MASTER_COMMIT=1 bash "$GUARD" check
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"FW_ALLOW_MASTER_COMMIT"* ]]
}

# --- usage guard ---

@test "usage: non-'check' arg → exit 2" {
    run env PROJECT_ROOT="$REPO" bash "$GUARD" bogus
    [ "$status" -eq 2 ]
}
