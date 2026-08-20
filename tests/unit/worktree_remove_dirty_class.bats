#!/usr/bin/env bats
# T-2831 -- `fw worktree remove` must classify uncommitted dirt before ever
# attempting `git worktree remove`. Uncommitted work is invisible to the
# T-2829 strand guard (commits only) and git's own dirty refusal names nothing
# -- exactly the shape that trains --force, which then silently discards
# whatever is dirty via `git worktree remove --force`.
#
# ── SUPERSEDED IN PART BY T-3102 ─────────────────────────────────────────────
# T-2831 originally split dirt into "regenerable machine-local state" (refused
# without --force, proceeds with it) and "content registers" -- `.tasks/**`,
# `decisions.yaml`, `feedback-stream.yaml` -- refused UNCONDITIONALLY on the
# theory that they were irreplaceable content.
#
# T-2822's adopted GO makes that theory wrong for the worktree copy
# specifically: governance state inside a linked worktree is NON-AUTHORITATIVE
# by construction (master holds the authoritative copy, and nothing ever reads
# the worktree's fork back). Refusing on it made --force routine on EVERY
# worktree (OBS-177), and --force then destroyed genuinely unlanded commits.
#
# So under T-3102 the split is GOVERNANCE (.context/**, .tasks/**) vs SOURCE:
#   - GOVERNANCE -> does NOT block; discarded with a summary line
#   - SOURCE     -> refused UNCONDITIONALLY, --force included
#
# T-2831's actual invariant -- "never silently discard uncommitted work, and
# --force is the strand-override flag, not a content-discard action (AC3)" --
# is unchanged and is what this file still pins, now over the SOURCE class.
# The governance side is covered in depth by
# tests/unit/t3102_worktree_governance_dirt.bats.

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
    mkdir -p "$REPO/.context/working" "$REPO/.context/project" "$REPO/.tasks/active" \
             "$REPO/lib" "$REPO/docs/context"
    echo a > "$REPO/a.txt"
    echo "echo hi" > "$REPO/lib/thing.sh"
    echo "notes" > "$REPO/docs/context/notes.md"
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

# SUPERSEDED SHAPE (was: "regenerable-only dirt refused without --force").
# session.yaml is governance, and governance no longer blocks at all -- so the
# case that used to need --force now needs nothing. Kept as a regression pin
# that the OBS-177 --force-training pressure is genuinely gone.
@test "governance dirt alone no longer forces the operator to reach for --force" {
    _mk_pushed_wt wt-regen
    echo "focus: T-9999" > "$REPO/.claude/worktrees/wt-regen/.context/working/session.yaml"

    # Precondition (T-2828 lesson): the dirt is genuinely there before we assert.
    run git -C "$REPO/.claude/worktrees/wt-regen" status --porcelain
    [[ "$output" == *"session.yaml"* ]]

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-regen"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [[ "$output" == *"governance file(s) dirty"* ]]
    [ ! -d "$REPO/.claude/worktrees/wt-regen" ]
}

# T-2831 AC3, preserved verbatim in intent, now over the SOURCE class.
@test "source dirt: refused, names files; --force does NOT bypass" {
    _mk_pushed_wt wt-content
    echo "echo changed" > "$REPO/.claude/worktrees/wt-content/lib/thing.sh"
    echo "print(1)" > "$REPO/.claude/worktrees/wt-content/scratch.py"

    # Precondition: both files genuinely dirty (one modified/tracked, one untracked).
    # --untracked-files=all matches what _wt_dirty_summary itself queries -- plain
    # `status --porcelain` collapses a wholly-untracked dir to `?? dir/`, which
    # would make this precondition pass without ever proving the file is visible.
    run git -C "$REPO/.claude/worktrees/wt-content" status --porcelain --untracked-files=all
    [[ "$output" == *"lib/thing.sh"* ]]
    [[ "$output" == *"scratch.py"* ]]

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-content"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"uncommitted SOURCE"* ]]
    [[ "$output" == *"lib/thing.sh"* ]]
    [[ "$output" == *"scratch.py"* ]]
    [[ "$output" == *"will NOT discard"* ]]
    [ -d "$REPO/.claude/worktrees/wt-content" ]

    # --force is the strand-override flag, NOT a content-discard action: still refused.
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-content --force"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"uncommitted SOURCE"* ]]
    [ -d "$REPO/.claude/worktrees/wt-content" ]
}

# SUPERSEDED SHAPE (was: feedback-stream.yaml must not be misclassified as
# regenerable). Under T-3102 it IS governance and IS discardable. The
# misclassification risk that remains is the mirror image: a path that merely
# LOOKS like governance must not be swept into the discardable class.
@test "governance look-alike outside the governance tree is NOT misclassified as governance" {
    _mk_pushed_wt wt-lookalike
    echo "changed notes" > "$REPO/.claude/worktrees/wt-lookalike/docs/context/notes.md"

    run git -C "$REPO/.claude/worktrees/wt-lookalike" status --porcelain
    [[ "$output" == *"notes.md"* ]]

    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-lookalike --force"
    [ "$status" -eq 1 ]
    [[ "$output" == *"uncommitted SOURCE"* ]]
    [[ "$output" == *"docs/context/notes.md"* ]]
    [ -d "$REPO/.claude/worktrees/wt-lookalike" ]
}

@test "clean worktree: dirty classification is silent, removal proceeds as before" {
    _mk_pushed_wt wt-clean
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && PROJECT_ROOT='$REPO' do_worktree_remove wt-clean"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed worktree"* ]]
    [ ! -d "$REPO/.claude/worktrees/wt-clean" ]
}
