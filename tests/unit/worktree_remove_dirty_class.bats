#!/usr/bin/env bats
# T-2831 -- `fw worktree remove` must classify uncommitted dirt before ever
# attempting `git worktree remove`. Uncommitted work is invisible to the
# T-2829 strand guard (commits only) and git's own dirty refusal names nothing
# -- exactly the shape that trains --force, which then silently discards
# whatever is dirty via `git worktree remove --force`.
#
# Two classes, per AC:
#   - regenerable machine-local state (counters, session.yaml, focus.yaml, ...)
#     -> refused WITHOUT --force (names the safe remedy), proceeds WITH --force
#   - content registers (.tasks/**, decisions.yaml, feedback-stream.yaml, and
#     anything outside .context/working/) -> refused UNCONDITIONALLY, --force
#     included, because --force is the strand-override flag, not a
#     content-discard action (AC3).

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
    mkdir -p "$REPO/.context/working" "$REPO/.context/project" "$REPO/.tasks/active"
    echo a > "$REPO/a.txt"
    echo "focus: none" > "$REPO/.context/working/session.yaml"
    echo "decisions: []" > "$REPO/.context/project/decisions.yaml"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m base
    git -C "$REPO" remote add origin "$REMOTE"
    git -C "$REPO" push -q origin master

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

# helper: create a worktree on branch <name> off master, fully pushed (so the
# T-2829 strand guard is satisfied and any refusal below comes from the dirty
# check alone, not commit reachability).
_mk_pushed_wt() {
    local name="$1"
    git -C "$REPO" worktree add -q -b "$name" "$REPO/.claude/worktrees/$name" master
    git -C "$REPO/.claude/worktrees/$name" push -q origin "$name"
}

@test "regenerable-only dirt: refused without --force, names safe remedy; --force proceeds" {
    _mk_pushed_wt wt-regen
    echo "focus: T-9999" > "$REPO/.claude/worktrees/wt-regen/.context/working/session.yaml"

    # Precondition (T-2828 lesson): the dirt is genuinely there before we assert.
    run git -C "$REPO/.claude/worktrees/wt-regen" status --porcelain
    [[ "$output" == *"session.yaml"* ]]

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-regen"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"regenerable machine-local state is dirty"* ]]
    [[ "$output" == *"session.yaml"* ]]
    [[ "$output" == *"Safe remedy"* ]]
    # worktree survives the refusal
    [ -d "$REPO/.claude/worktrees/wt-regen" ]

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-regen --force"
    [ "$status" -eq 0 ]
    [ ! -d "$REPO/.claude/worktrees/wt-regen" ]
}

@test "content-register dirt: refused, names files + diffstat; --force does NOT bypass" {
    _mk_pushed_wt wt-content
    echo 'decisions: [{id: D-1}]' > "$REPO/.claude/worktrees/wt-content/.context/project/decisions.yaml"
    mkdir -p "$REPO/.claude/worktrees/wt-content/.tasks/active"
    echo "status: started-work" > "$REPO/.claude/worktrees/wt-content/.tasks/active/T-9-scratch.md"

    # Precondition: both files genuinely dirty (one modified/tracked, one untracked).
    # --untracked-files=all matches what _wt_dirty_summary itself queries -- plain
    # `status --porcelain` collapses a wholly-untracked dir to `?? .tasks/`, which
    # would make this precondition pass without ever proving the file is visible.
    run git -C "$REPO/.claude/worktrees/wt-content" status --porcelain --untracked-files=all
    [[ "$output" == *"decisions.yaml"* ]]
    [[ "$output" == *"T-9-scratch.md"* ]]

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-content"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"content-register file(s) dirty"* ]]
    [[ "$output" == *"decisions.yaml"* ]]
    [[ "$output" == *"T-9-scratch.md"* ]]
    [[ "$output" == *"untracked"* ]]
    [[ "$output" == *"will NOT discard them"* ]]
    [ -d "$REPO/.claude/worktrees/wt-content" ]

    # --force is the strand-override flag, NOT a content-discard action: still refused.
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-content --force"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"content-register"* ]]
    [ -d "$REPO/.claude/worktrees/wt-content" ]
}

@test "content register inside .context/working/ (feedback-stream.yaml) is NOT misclassified as regenerable" {
    _mk_pushed_wt wt-feedback
    echo "- auto_tick: T-1:0" > "$REPO/.claude/worktrees/wt-feedback/.context/working/feedback-stream.yaml"

    run git -C "$REPO/.claude/worktrees/wt-feedback" status --porcelain
    [[ "$output" == *"feedback-stream.yaml"* ]]

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-feedback --force"
    [ "$status" -eq 1 ]
    [[ "$output" == *"content-register"* ]]
    [[ "$output" == *"feedback-stream.yaml"* ]]
}

@test "clean worktree: dirty classification is silent, removal proceeds as before" {
    _mk_pushed_wt wt-clean
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-clean"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [ ! -d "$REPO/.claude/worktrees/wt-clean" ]
}
