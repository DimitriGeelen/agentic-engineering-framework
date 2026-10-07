#!/usr/bin/env bats
# T-3959 (1409): every dispatched worker that was not a review worker started a
# Watchtower (bound 0.0.0.0) and a sidecar for its worktree, and both outlived the
# worktree. The Watchtower exemption is now keyed to "is a dispatched worker"; the
# sidecar stays (R14) but is stopped when its worktree is removed, and the receiver
# exits by itself once its project is gone (test_receiver_orphan_t3959.py).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    CALLS="$TEST_TEMP_DIR/calls"
    STUB="$TEST_TEMP_DIR/watchtower.sh"
    printf '#!/bin/bash\necho "watchtower $1 root=$PROJECT_ROOT" >> "%s"\n[ "$1" = status ] && exit 3\nexit 0\n' "$CALLS" > "$STUB"
    chmod +x "$STUB"
    SIDECAR_STUB="$TEST_TEMP_DIR/sidecar_cli.py"
    printf 'import os, sys\nopen("%s", "a").write("sidecar %%s root=%%s\\n" %% (" ".join(sys.argv[1:]), os.environ.get("PROJECT_ROOT")))\n' \
        "$CALLS" > "$SIDECAR_STUB"
    export FW_WATCHTOWER_SH="$STUB" FW_WT_SIDECAR_CLI="$SIDECAR_STUB"
    unset FW_WATCHTOWER_ENSURE FW_REVIEW_WORKER FW_DISPATCHED_WORKER
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_ensure() {   # run fw_watchtower_ensure in a fresh project
    local p="$TEST_TEMP_DIR/proj"
    mkdir -p "$p/.context/working"
    bash -c "export PROJECT_ROOT='$p' FRAMEWORK_ROOT='$FRAMEWORK_ROOT'; source '$FRAMEWORK_ROOT/lib/watchtower-ensure.sh'; fw_watchtower_ensure"
}

@test "T-3959: a dispatched worker (any task type) never starts a Watchtower" {
    FW_DISPATCHED_WORKER=1 _ensure
    ! grep -q "watchtower start" "$CALLS" 2>/dev/null
}

@test "T-3959/control: an ordinary session still starts one" {
    _ensure
    grep -q "watchtower start" "$CALLS"
}

@test "T-3959: dispatch marks every worker, outside the review-only branch" {
    f="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    # Same indentation as the unconditional sidecar-id line, and before the review-only
    # FW_REVIEW_WORKER line: written for every worker, not inside the review branch.
    sid=$(grep -n "printf 'export FW_SIDECAR_AGENT_ID" "$f" | head -1)
    mk=$(grep -n "printf 'export FW_DISPATCHED_WORKER" "$f" | head -1)
    rv=$(grep -n "printf 'export FW_REVIEW_WORKER" "$f" | head -1 | cut -d: -f1)
    [ -n "$sid" ] && [ -n "$mk" ] && [ -n "$rv" ]
    [ "${mk%%:*}" -gt "${sid%%:*}" ] && [ "${mk%%:*}" -lt "$rv" ]
    ind() { local l="${1#*:}"; echo "${l%%printf*}"; }
    [ "$(ind "$mk")" = "$(ind "$sid")" ]
    # a review worker's env is validated against an allowlist; the marker must be on it
    python3 -c "import sys; sys.path.insert(0, '$FRAMEWORK_ROOT'); from lib import verdict_ledger as v; assert 'FW_DISPATCHED_WORKER' in v._RUNTIME_ENV_KEYS"
}

_repo_with_worktree() {
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    REMOTE="$TEST_TEMP_DIR/remote.git"; REPO="$TEST_TEMP_DIR/repo"
    git init -q --bare -b master "$REMOTE"
    git init -q -b master "$REPO"
    printf '.context/\n' > "$REPO/.gitignore"; echo a > "$REPO/a.txt"
    git -C "$REPO" add -A && git -C "$REPO" commit -qm base
    git -C "$REPO" remote add origin "$REMOTE" && git -C "$REPO" push -q origin master
    WT="$REPO/.claude/worktrees/w1"
    git -C "$REPO" worktree add -q -b w1 "$WT" master
    git -C "$WT" push -q origin w1
}

@test "T-3959: fw worktree remove stops the worktree's sidecar and Watchtower first" {
    _repo_with_worktree
    mkdir -p "$WT/.context/sidecar" "$WT/.context/working"
    echo 999999 > "$WT/.context/working/watchtower.pid"
    run bash -c "cd '$REPO' && export FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$REPO'; source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_remove w1"
    [ "$status" -eq 0 ]
    [ ! -d "$WT" ]
    grep -q "sidecar stop --quiet root=$WT" "$CALLS"
    grep -q "watchtower stop root=$WT" "$CALLS"
}

@test "T-3959/control: a worktree with no services is removed without calling either" {
    _repo_with_worktree
    run bash -c "cd '$REPO' && export FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$REPO'; source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_remove w1"
    [ "$status" -eq 0 ]
    [ ! -d "$WT" ]
    [ ! -f "$CALLS" ]
}
