#!/usr/bin/env bats
# T-100142 (C1 of T-100139) — fw integrate run deletes the landed source branch.
#
# Contract:
#   default + verified landing (--push OK, tip ⊆ origin/target):
#       remote branch ref deleted (when present) → worktree removed → branch deleted
#   --keep-branch:       branch + worktree survive
#   no --push:           branch kept (landing not verified against origin)
#   failed integration:  branch untouched (run refuses before any mutation)
#   unmerged tip:        never force-deleted (explicit is-ancestor re-check)
#
# Fixture mirrors t2474_integrate_run_landing.bats: ORIGIN bare, MAIN on a
# session branch, wt-master holding master, wt-feat on feat where run executes.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    INTEGRATE="$FRAMEWORK_ROOT/lib/integrate.py"

    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

    ROOT="$(mktemp -d)"
    ORIGIN="$ROOT/origin.git"
    MAIN="$ROOT/main"
    WT_MASTER="$ROOT/wt-master"
    WT_FEAT="$ROOT/wt-feat"

    git init -q --bare -b master "$ORIGIN"
    git init -q -b master "$MAIN"
    mkdir -p "$MAIN/.context/working" "$MAIN/bin"

    cat > "$MAIN/bin/fw" <<EOF
#!/bin/bash
exit 0
EOF
    chmod +x "$MAIN/bin/fw"
    export FW_BIN="$MAIN/bin/fw"

    echo a > "$MAIN/a.txt"
    echo base > "$MAIN/foo.sh"
    git -C "$MAIN" add a.txt foo.sh bin/fw
    git -C "$MAIN" commit -q -m base
    BASE="$(git -C "$MAIN" rev-parse HEAD)"

    echo "master only" > "$MAIN/m.txt"
    git -C "$MAIN" add m.txt
    git -C "$MAIN" commit -q -m "master diverge"
    git -C "$MAIN" remote add origin "$ORIGIN"
    git -C "$MAIN" push -q origin master

    git -C "$MAIN" checkout -q -b session

    git -C "$MAIN" worktree add -q "$WT_MASTER" master
    git -C "$MAIN" worktree add -q -b feat "$WT_FEAT" "$BASE"
    echo "feat only" > "$WT_FEAT/f.txt"
    git -C "$WT_FEAT" add f.txt
    git -C "$WT_FEAT" commit -q -m "feat diverge"
}

teardown() {
    [ -n "$ROOT" ] && rm -rf "$ROOT" 2>/dev/null || true
}

_branch_exists() { git -C "$MAIN" show-ref --verify --quiet "refs/heads/$1"; }

@test "default: verified landing deletes branch, worktree, and remote ref" {
    # publish the branch itself so a remote ref exists to clean up
    git -C "$WT_FEAT" push -q origin feat
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branch cleanup:"* ]]
    [[ "$output" == *"origin/feat  deleted"* ]]
    [[ "$output" == *"worktree $WT_FEAT  removed"* ]]
    [[ "$output" == *"feat  deleted"* ]]
    ! _branch_exists feat
    [ ! -d "$WT_FEAT" ]
    ! git -C "$MAIN" show-ref --verify --quiet "refs/remotes/origin/feat"
    # remote side really gone
    ! git -C "$ORIGIN" show-ref --verify --quiet "refs/heads/feat"
}

@test "--keep-branch: branch and worktree survive a pushed landing" {
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push --keep-branch"
    [ "$status" -eq 0 ]
    [[ "$output" == *"kept (--keep-branch)"* ]]
    _branch_exists feat
    [ -d "$WT_FEAT" ]
}

@test "no --push: branch kept (landing not verified against origin)" {
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master"
    [ "$status" -eq 0 ]
    [[ "$output" == *"kept — landing not pushed"* ]]
    _branch_exists feat
    [ -d "$WT_FEAT" ]
}

@test "failed integration (needs-human) leaves the branch untouched" {
    # both sides change foo.sh → preflight verdict 2 → run refuses pre-mutation
    echo "master side" >> "$WT_MASTER/foo.sh"
    git -C "$WT_MASTER" commit -qam "master foo"
    git -C "$WT_MASTER" push -q origin master
    echo "feat side" >> "$WT_FEAT/foo.sh"
    git -C "$WT_FEAT" commit -qam "feat foo"
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push"
    [ "$status" -eq 2 ]
    [[ "$output" != *"Branch cleanup:"* ]]
    _branch_exists feat
    [ -d "$WT_FEAT" ]
}

@test "unmerged tip is never force-deleted (is-ancestor re-check)" {
    # Call the cleanup helper directly with pushed=True while feat is NOT
    # contained in origin/master — the explicit containment check must refuse.
    run bash -c "cd '$WT_FEAT' && PYTHONPATH='$FRAMEWORK_ROOT/lib' python3 -c \"
import integrate
integrate._cleanup_branch('feat', 'master', True, False)
\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"kept — tip not contained in origin/master"* ]]
    _branch_exists feat
    [ -d "$WT_FEAT" ]
}

@test "dry-run plan names the branch-cleanup step" {
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push --dry-run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"delete landed source branch feat"* ]]
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push --keep-branch --dry-run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"keep source branch (--keep-branch)"* ]]
}
