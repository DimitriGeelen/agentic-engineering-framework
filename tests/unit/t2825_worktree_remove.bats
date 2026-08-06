#!/usr/bin/env bats
# T-2825 (G-076) — unit tests for lib/worktree.sh:do_worktree_remove (fw worktree
# remove). `git worktree remove` alone has no opinion about whether the branch it
# points at is reachable anywhere else; this wrapper refuses removal when the
# worktree's branch holds commits absent from EVERY configured remote, which is
# exactly the shape that stranded T-2428's 6 commits for 5 weeks.
#
# Hermetic: a real bare repo stands in for "origin" so refs/remotes/origin/<branch>
# reflects genuine push state — no network, no dependency on the live framework.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # shellcheck source=../../lib/worktree.sh
    source "$FRAMEWORK_ROOT/lib/worktree.sh"

    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

    FIX="$(mktemp -d)"
    REMOTE="$FIX/remote.git"
    REPO="$FIX/repo"

    git init -q --bare -b master "$REMOTE"

    git init -q -b master "$REPO"
    echo a > "$REPO/a.txt"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m base
    git -C "$REPO" remote add origin "$REMOTE"
    git -C "$REPO" push -q origin master

    # PROJECT_ROOT drives where the Tier-2 bypass log is written.
    export PROJECT_ROOT="$REPO"
}

teardown() {
    if [ -n "${REPO:-}" ] && [ -d "$REPO" ]; then
        git -C "$REPO" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r p; do
            [ "$p" != "$REPO" ] && rm -rf "$p" 2>/dev/null || true
        done
    fi
    [ -n "${FIX:-}" ] && rm -rf "$FIX" 2>/dev/null || true
}

# helper: create a worktree on branch <name> off master
_mk_wt() {
    local name="$1"
    git -C "$REPO" worktree add -q -b "$name" "$REPO/.claude/worktrees/$name" master
}

@test "unpushed branch: removal is REFUSED, worktree and branch both survive" {
    _mk_wt feat
    echo change > "$REPO/.claude/worktrees/feat/a.txt"
    git -C "$REPO/.claude/worktrees/feat" commit -qam "unpushed change"

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove feat"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"not on any remote"* ]]
    # worktree directory is untouched — the whole point of the guard
    [ -d "$REPO/.claude/worktrees/feat" ]
    git -C "$REPO" show-ref --verify --quiet refs/heads/feat
}

@test "fully pushed branch: removal SUCCEEDS, branch is kept" {
    _mk_wt feat2
    echo change > "$REPO/.claude/worktrees/feat2/a.txt"
    git -C "$REPO/.claude/worktrees/feat2" commit -qam "pushed change"
    git -C "$REPO/.claude/worktrees/feat2" push -q origin feat2

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove feat2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [ ! -d "$REPO/.claude/worktrees/feat2" ]
    # branch is kept — remove is a worktree-only teardown, branch deletion stays Tier-0
    git -C "$REPO" show-ref --verify --quiet refs/heads/feat2
}

@test "branch pushed with zero commits ahead: removal SUCCEEDS (nothing to strand)" {
    _mk_wt feat3
    git -C "$REPO/.claude/worktrees/feat3" push -q origin feat3
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove feat3"
    [ "$status" -eq 0 ]
    [ ! -d "$REPO/.claude/worktrees/feat3" ]
}

@test "--force overrides the refusal, removes the worktree, and logs a Tier-2 bypass entry" {
    _mk_wt feat4
    echo change > "$REPO/.claude/worktrees/feat4/a.txt"
    git -C "$REPO/.claude/worktrees/feat4" commit -qam "unpushed change"

    mkdir -p "$REPO/.context/working"
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove feat4 --force"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--force override"* ]]
    [ ! -d "$REPO/.claude/worktrees/feat4" ]
    git -C "$REPO" show-ref --verify --quiet refs/heads/feat4

    [ -f "$REPO/.context/working/.gate-bypass-log.yaml" ]
    grep -q "do_worktree_remove" "$REPO/.context/working/.gate-bypass-log.yaml"
    grep -q "feat4" "$REPO/.context/working/.gate-bypass-log.yaml"
}

@test "no remotes configured at all: fails closed (treated as unpushed)" {
    git -C "$REPO" remote remove origin
    _mk_wt feat5
    echo change > "$REPO/.claude/worktrees/feat5/a.txt"
    git -C "$REPO/.claude/worktrees/feat5" commit -qam "change, no remote to check against"

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove feat5"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"no git remotes configured"* ]]
}

@test "unknown name errors clearly, does not touch git state" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_remove no-such-worktree"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no linked worktree matches"* ]]
}

@test "missing argument prints usage and exits 2" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_remove"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
