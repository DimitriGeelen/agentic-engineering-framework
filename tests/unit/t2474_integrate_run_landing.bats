#!/usr/bin/env bats
# T-2474 — unit tests for lib/integrate.py:_land (fw integrate run hybrid landing).
#
# Hermetic multi-worktree fixture:
#   ORIGIN   bare repo (push target → zone 1)
#   MAIN     main checkout, on a SESSION branch (off-master → zone 3 report)
#   wt-master  linked worktree holding `master` (the master-holder → zone 2)
#   wt-feat    linked worktree on `feat` (where integrate runs)
#
# Hybrid contract:
#   zone 2 (master worktree): auto-FF when clean AND pushed; report when dirty/no-push.
#   zone 3 (MAIN off-master): report-only go-live command; never auto-mutated.

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

    # vendor-refresh stub: harmless no-op, touches a sentinel on `vendor self`
    cat > "$MAIN/bin/fw" <<EOF
#!/bin/bash
[ "\$1" = "vendor" ] && [ "\$2" = "self" ] && touch "$ROOT/.vendor-ran"
exit 0
EOF
    chmod +x "$MAIN/bin/fw"
    export FW_BIN="$MAIN/bin/fw"

    # base commit = merge-base
    echo a > "$MAIN/a.txt"
    echo base > "$MAIN/foo.sh"
    echo 0 > "$MAIN/.context/working/.hook-counter"
    git -C "$MAIN" add a.txt foo.sh .context/working/.hook-counter bin/fw
    git -C "$MAIN" commit -q -m base
    BASE="$(git -C "$MAIN" rev-parse HEAD)"

    # master diverges (a new file only on master), publish to origin
    echo "master only" > "$MAIN/m.txt"
    git -C "$MAIN" add m.txt
    git -C "$MAIN" commit -q -m "master diverge"
    MASTER_HEAD="$(git -C "$MAIN" rev-parse HEAD)"
    git -C "$MAIN" remote add origin "$ORIGIN"
    git -C "$MAIN" push -q origin master

    # MAIN moves OFF master onto a session branch (frees `master` for a worktree)
    git -C "$MAIN" checkout -q -b session
    SESSION_HEAD="$(git -C "$MAIN" rev-parse HEAD)"

    # master-holder worktree + feat worktree (feat diverges with a disjoint file)
    git -C "$MAIN" worktree add -q "$WT_MASTER" master
    git -C "$MAIN" worktree add -q -b feat "$WT_FEAT" "$BASE"
    echo "feat only" > "$WT_FEAT/f.txt"
    git -C "$WT_FEAT" add f.txt
    git -C "$WT_FEAT" commit -q -m "feat diverge"
}

teardown() {
    [ -n "$ROOT" ] && rm -rf "$ROOT" 2>/dev/null || true
}

@test "zone 2: --push auto-FFs a CLEAN master-holding worktree to the branch" {
    # T-100142: default branch cleanup deletes wt-feat after landing — use
    # --keep-branch so feat's HEAD is still inspectable post-run.
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push --keep-branch"
    [ "$status" -eq 0 ]
    # wt-master advanced to the integrated feat HEAD
    local feat_head wtm_head
    feat_head="$(git -C "$WT_FEAT" rev-parse HEAD)"
    wtm_head="$(git -C "$WT_MASTER" rev-parse HEAD)"
    [ "$feat_head" = "$wtm_head" ]
    [[ "$output" == *"FF'd to feat"* ]]
}

@test "zone 2: --push does NOT touch a DIRTY master-holding worktree (reports instead)" {
    echo "uncommitted" > "$WT_MASTER/scratch.txt"   # untracked → dirty
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push"
    [ "$status" -eq 0 ]
    # wt-master HEAD unchanged (still the pre-run master commit)
    [ "$(git -C "$WT_MASTER" rev-parse HEAD)" = "$MASTER_HEAD" ]
    [[ "$output" == *"DIRTY"* ]]
}

@test "zone 3: MAIN off-master is REPORTED (go-live command), never mutated" {
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push"
    [ "$status" -eq 0 ]
    # MAIN still on session at the same commit — not touched
    [ "$(git -C "$MAIN" rev-parse HEAD)" = "$SESSION_HEAD" ]
    [ "$(git -C "$MAIN" rev-parse --abbrev-ref HEAD)" = "session" ]
    # report names MAIN's path + a merge command, and flags not-live
    [[ "$output" == *"host (MAIN)"* ]]
    [[ "$output" == *"NOT live"* ]]
    [[ "$output" == *"$MAIN"* ]]
    [[ "$output" == *"git merge feat"* ]]
}

@test "landing summary block prints each zone's state" {
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master --push"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Landing:"* ]]
    [[ "$output" == *"origin/master"* ]]
    [[ "$output" == *"master worktree"* ]]
    [[ "$output" == *"host (MAIN)"* ]]
}

@test "no --push: zone 2 master worktree is NOT mutated even when clean" {
    run bash -c "cd '$WT_FEAT' && python3 '$INTEGRATE' run master"
    [ "$status" -eq 0 ]
    # clean master-holder left at the pre-run commit (no FF without --push)
    [ "$(git -C "$WT_MASTER" rev-parse HEAD)" = "$MASTER_HEAD" ]
    [[ "$output" == *"no --push"* ]]
}
