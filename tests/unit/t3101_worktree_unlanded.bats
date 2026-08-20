#!/usr/bin/env bats
# T-3101 (slice 2 of T-2822 F5): worktree-unlanded — lib/branch-hygiene.sh
#
# The gap: the linked-worktree loop reported only `worktree-merged` (the
# deletable case) and said NOTHING about a worktree holding commits that are not
# on master. Two such worktrees in the origin repo held 43 unlanded commits for
# five weeks with no surface reporting a count or an age.
#
# Fixture: bare ORIGIN + CLONE with a master lineage, real `git worktree add`.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIX="$BATS_TEST_TMPDIR/fix"
    ORIGIN="$FIX/origin.git"
    CLONE="$FIX/clone"
    mkdir -p "$FIX"
    git init --bare -q -b master "$ORIGIN"
    git clone -q "$ORIGIN" "$CLONE" 2>/dev/null
    cd "$CLONE"
    git config user.email t@t && git config user.name t
    git checkout -q -b master
    echo one > f.txt && git add f.txt && git commit -qm c1
    echo two >> f.txt && git commit -qam c2
    git push -q origin master
    # shellcheck disable=SC1091
    . "$REPO_ROOT/lib/branch-hygiene.sh"
}

# Explicit-return refute: `! cmd | grep -q X` in non-final position is INERT
# under `set -e` and bats only checks the body's last line, so a leak would pass
# silently. Same helper and same reasoning as t100143_branch_hygiene.bats.
_refute_line() {
    if echo "$output" | grep -q "$1"; then
        echo "LEAK: output matched '$1' but should not have:" >&2
        echo "$output" >&2
        return 1
    fi
    return 0
}

# Add a linked worktree on a NEW branch off master and put $1 commits on it.
_strand_worktree() {
    # NOTE: separate `local` statements on purpose. bash 5.2 does NOT make an
    # earlier name visible to a later RHS in the SAME `local` declaration
    # (`local a="$1" b="X/$a"` leaves b as "X/"), which silently produced an
    # empty worktree path here.
    local name="$1"
    local n="$2"
    local path="$FIX/$name"
    local i
    git -C "$CLONE" worktree add -q -b "$name" "$path" master
    git -C "$path" config user.email t@t && git -C "$path" config user.name t
    for i in $(seq 1 "$n"); do
        echo "$name-$i" > "$path/$name-$i.txt"
        git -C "$path" add "$name-$i.txt"
        git -C "$path" commit -qm "$name c$i"
    done
    echo "$path"
}

@test "T-3101: worktree with unlanded commits surfaces with path, branch, ahead and days" {
    local wt; wt=$(_strand_worktree strand-a 2)
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^worktree-unlanded $wt branch=strand-a ahead=2 days=0$"
}

@test "T-3101: fully landed worktree does NOT emit worktree-unlanded" {
    # Branch created off master with no unique commits: ahead=0, and it is an
    # ancestor of origin/master, so the merged arm owns it.
    git -C "$CLONE" worktree add -q -b landed-feat "$FIX/landed-feat" master
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    _refute_line "^worktree-unlanded"
}

@test "T-3101: precedence — a merged worktree reports merged only, never unlanded" {
    # Merged-but-behind: branch at master~1, an ancestor of origin/master.
    git -C "$CLONE" worktree add -q -b wt-merged "$FIX/wt-merged" HEAD~1
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^worktree-merged $FIX/wt-merged branch=wt-merged$"
    _refute_line "^worktree-unlanded $FIX/wt-merged"
    # and exactly one verdict for that path across BOTH worktree classes
    [ "$(echo "$output" | grep -c "^worktree-.* $FIX/wt-merged ")" -eq 1 ]
}

@test "T-3101: repo with no linked worktrees is silent on both worktree classes" {
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    _refute_line "^worktree-"
    [ -z "$output" ]
}

@test "T-3101: no origin/master but master present — base falls back, still correct" {
    local LOCAL="$FIX/localonly"
    git init -q -b master "$LOCAL"
    git -C "$LOCAL" config user.email t@t && git -C "$LOCAL" config user.name t
    echo x > "$LOCAL/x.txt" && git -C "$LOCAL" add x.txt && git -C "$LOCAL" commit -qm x
    git -C "$LOCAL" worktree add -q -b lo-strand "$FIX/lo-strand" master
    git -C "$FIX/lo-strand" config user.email t@t && git -C "$FIX/lo-strand" config user.name t
    echo s > "$FIX/lo-strand/s.txt"
    git -C "$FIX/lo-strand" add s.txt && git -C "$FIX/lo-strand" commit -qm s
    run fw_branch_hygiene "$LOCAL"
    [ "$status" -eq 0 ]
    # no origin/master anywhere in this repo — the finding proves master was used
    ! git -C "$LOCAL" rev-parse --verify -q origin/master >/dev/null 2>&1
    echo "$output" | grep -q "^worktree-unlanded $FIX/lo-strand branch=lo-strand ahead=1 days=0$"
}

@test "T-3101: neither origin/master nor master — silent, exit 0, no stderr spew" {
    local NOM="$FIX/nomaster"
    git init -q -b trunk "$NOM"
    git -C "$NOM" config user.email t@t && git -C "$NOM" config user.name t
    echo x > "$NOM/x.txt" && git -C "$NOM" add x.txt && git -C "$NOM" commit -qm x
    git -C "$NOM" worktree add -q -b nm-strand "$FIX/nm-strand" trunk
    git -C "$FIX/nm-strand" config user.email t@t && git -C "$FIX/nm-strand" config user.name t
    echo s > "$FIX/nm-strand/s.txt"
    git -C "$FIX/nm-strand" add s.txt && git -C "$FIX/nm-strand" commit -qm s
    local err="$BATS_TEST_TMPDIR/err.txt"
    run bash -c ". '$REPO_ROOT/lib/branch-hygiene.sh'; fw_branch_hygiene '$NOM' 2>'$err'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -s "$err" ]
}

@test "T-3101: ahead is exact — 7 known commits report ahead=7" {
    local wt; wt=$(_strand_worktree strand-seven 7)
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^worktree-unlanded $wt branch=strand-seven ahead=7 days=0$"
    # off-by-one guard: neither neighbour value may appear for this path
    _refute_line "^worktree-unlanded $wt branch=strand-seven ahead=6 "
    _refute_line "^worktree-unlanded $wt branch=strand-seven ahead=8 "
}

@test "T-3101: days is exact — a commit dated 12 days ago reports days=12" {
    local path="$FIX/strand-old"
    git -C "$CLONE" worktree add -q -b strand-old "$path" master
    git -C "$path" config user.email t@t && git -C "$path" config user.name t
    local when
    when=$(date -d '12 days ago' --iso-8601=seconds)
    echo old > "$path/old.txt"
    git -C "$path" add old.txt
    GIT_COMMITTER_DATE="$when" GIT_AUTHOR_DATE="$when" git -C "$path" commit -qm old
    run fw_branch_hygiene "$CLONE"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^worktree-unlanded $path branch=strand-old ahead=1 days=12$"
    _refute_line "days=0"
}
