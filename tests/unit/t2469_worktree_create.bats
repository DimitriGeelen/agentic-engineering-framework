#!/usr/bin/env bats
# T-2469 — unit tests for lib/worktree.sh:do_worktree_create (fw worktree create).
#
# Hermetic: builds a synthetic git repo (master with a committed .agentic-framework/
# tree + a stub bin/fw that no-ops `vendor self`) in a temp dir and exercises
# do_worktree_create directly. No dependency on the live framework topology.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # shellcheck source=../../lib/worktree.sh
    source "$FRAMEWORK_ROOT/lib/worktree.sh"

    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

    REPO="$(mktemp -d)"
    git -C "$REPO" init -q -b master
    mkdir -p "$REPO/bin" "$REPO/.agentic-framework/lib"

    # stub bin/fw: no-op `vendor self` so the create step's vendor-sync succeeds
    printf '#!/bin/bash\nexit 0\n' > "$REPO/bin/fw"
    chmod +x "$REPO/bin/fw"
    echo "vendored" > "$REPO/.agentic-framework/lib/marker"
    echo a > "$REPO/a.txt"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m "base"

    # mimic the real host: main checkout on a session branch, not master
    git -C "$REPO" checkout -q -b session-branch
}

teardown() {
    if [ -n "$REPO" ]; then
        # remove linked worktrees first, then the repo
        git -C "$REPO" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r p; do
            [ "$p" != "$REPO" ] && rm -rf "$p" 2>/dev/null || true
        done
        rm -rf "$REPO" 2>/dev/null || true
    fi
}

@test "create succeeds: makes worktree dir, branch, and vendored .agentic-framework/" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_create feat"
    [ "$status" -eq 0 ]
    # worktree directory exists under the main checkout
    [ -d "$REPO/.claude/worktrees/feat" ]
    # branch follows the convention
    git -C "$REPO" show-ref --verify --quiet refs/heads/worktree-feat
    # vendored tree is present in the new worktree (from the base checkout)
    [ -f "$REPO/.claude/worktrees/feat/.agentic-framework/lib/marker" ]
}

@test "create branches from master by default even when main is on a session branch" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_create feat"
    [ "$status" -eq 0 ]
    # worktree-feat's HEAD equals master's HEAD (branched from master, not session-branch)
    local m wt
    m="$(git -C "$REPO" rev-parse master)"
    wt="$(git -C "$REPO/.claude/worktrees/feat" rev-parse HEAD)"
    [ "$m" = "$wt" ]
}

@test "duplicate name errors clearly (does not clobber)" {
    bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_create feat" >/dev/null 2>&1
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_create feat"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "invalid name (slash) is rejected with exit 2" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_create 'bad/name'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"name must be"* ]]
}

@test "missing name prints usage and exits 2" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_create"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}

@test "--from <ref> branches from the given ref" {
    # add a second commit on session-branch so it diverges from master
    echo b > "$REPO/b.txt"
    git -C "$REPO" add b.txt
    git -C "$REPO" commit -q -m "session diverge"
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_create feat2 --from session-branch"
    [ "$status" -eq 0 ]
    local sb wt
    sb="$(git -C "$REPO" rev-parse session-branch)"
    wt="$(git -C "$REPO/.claude/worktrees/feat2" rev-parse HEAD)"
    [ "$sb" = "$wt" ]
}
