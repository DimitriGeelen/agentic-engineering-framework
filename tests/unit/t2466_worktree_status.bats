#!/usr/bin/env bats
# T-2466 — unit tests for lib/worktree.sh:do_worktree_status (fw worktree status).
#
# Hermetic: builds a synthetic git repo with linked worktrees in a temp dir and
# exercises the status logic directly. No dependency on the live framework topology.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # shellcheck source=../../lib/worktree.sh
    source "$FRAMEWORK_ROOT/lib/worktree.sh"

    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

    REPO="$(mktemp -d)"
    git -C "$REPO" init -q -b master
    echo a > "$REPO/a.txt"
    git -C "$REPO" add a.txt
    git -C "$REPO" commit -q -m "initial"

    # main checkout moves to a session branch → NOT on master
    git -C "$REPO" checkout -q -b session-branch

    WT_MASTER="$(mktemp -d)"; rmdir "$WT_MASTER"
    WT_MERGED="$(mktemp -d)"; rmdir "$WT_MERGED"
    WT_UNMERGED="$(mktemp -d)"; rmdir "$WT_UNMERGED"

    # a worktree that holds master checked out (the master-lock)
    git -C "$REPO" worktree add -q "$WT_MASTER" master
    # a worktree at master's commit → merged + live
    git -C "$REPO" worktree add -q -b feat-merged "$WT_MERGED" master
    # a worktree with an extra commit not in master/session → unmerged + not live
    git -C "$REPO" worktree add -q -b feat-new "$WT_UNMERGED" master
    echo b > "$WT_UNMERGED/b.txt"
    git -C "$WT_UNMERGED" add b.txt
    git -C "$WT_UNMERGED" commit -q -m "extra"
}

teardown() {
    [ -n "$REPO" ] && rm -rf "$REPO" "$WT_MASTER" "$WT_MERGED" "$WT_UNMERGED" 2>/dev/null || true
}

@test "status reports MAIN branch and flags when not on master" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_status"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "MAIN"
    echo "$output" | grep -q "session-branch"
    echo "$output" | grep -q "NOT on master"
}

@test "status detects the master-lock holder worktree" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_status"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "master is checked out in a LINKED worktree"
    echo "$output" | grep -q "git push origin <branch>:master"
}

@test "status shows merged:yes for a worktree at master's commit" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_status"
    [ "$status" -eq 0 ]
    echo "$output" | grep -E "feat-merged .* merged:yes"
}

@test "status shows merged:no for a worktree with an unmerged commit" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_status"
    [ "$status" -eq 0 ]
    echo "$output" | grep -E "feat-new .* merged:no"
}

@test "status shows live:no for the unmerged worktree" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_status"
    [ "$status" -eq 0 ]
    echo "$output" | grep -E "feat-new .* live:no"
}

@test "--json emits parseable topology with expected keys" {
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_status --json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c '
import sys, json
d = json.load(sys.stdin)
assert set(d.keys()) == {"main", "master_holder", "linked_worktrees"}, d.keys()
assert d["main"]["branch"] == "session-branch", d["main"]
assert d["main"]["on_master"] is False
assert d["master_holder"] is not None
branches = {w["branch"]: w for w in d["linked_worktrees"]}
assert branches["feat-merged"]["merged"] == "yes"
assert branches["feat-new"]["merged"] == "no"
assert branches["feat-new"]["live"] == "no"
assert any(w["holds_master"] for w in d["linked_worktrees"])
print("ok")
'
}

@test "status exits 4 outside a git repository" {
    local nonrepo; nonrepo="$(mktemp -d)"
    run bash -c "cd '$nonrepo' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_status"
    rm -rf "$nonrepo"
    [ "$status" -eq 4 ]
    echo "$output" | grep -q "not in a git repository"
}

@test "do_worktree_doctor_line prints for a linked worktree and is silent for main" {
    # linked worktree → prints a line
    run bash -c "cd '$WT_UNMERGED' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_doctor_line"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "linked worktree:"
    echo "$output" | grep -q "feat-new"

    # main checkout → returns 1, no output
    run bash -c "cd '$REPO' && source '$FRAMEWORK_ROOT/lib/worktree.sh' && do_worktree_doctor_line"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}
