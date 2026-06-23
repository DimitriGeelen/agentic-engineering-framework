#!/usr/bin/env bats
# T-2471 — unit tests for lib/integrate.py:cmd_run (fw integrate run).
#
# Hermetic: builds a synthetic divergent git repo in a temp dir and drives
# integrate.py run directly. No framework git hooks are installed (fresh git
# init), so merge commits behave like production's MERGE_HEAD-exempt path.
# A stub bin/fw proves the vendor-refresh step fires without running real vendoring.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    INTEGRATE="$FRAMEWORK_ROOT/lib/integrate.py"

    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    # FW_BIN points the python's _vendor_refresh at a harmless stub, never the
    # real framework (which would run actual vendoring against the temp repo).
    unset FRAMEWORK_ROOT_ENV 2>/dev/null || true

    REPO="$(mktemp -d)"
    git -C "$REPO" init -q -b master
    mkdir -p "$REPO/.context/working" "$REPO/bin"

    # vendor-refresh stub: touch a sentinel when called `vendor self`
    cat > "$REPO/bin/fw" <<EOF
#!/bin/bash
[ "\$1" = "vendor" ] && [ "\$2" = "self" ] && touch "$REPO/.vendor-ran"
exit 0
EOF
    chmod +x "$REPO/bin/fw"
    export FW_BIN="$REPO/bin/fw"

    # base commit = merge-base
    echo a > "$REPO/a.txt"
    echo "base" > "$REPO/foo.sh"
    echo "0" > "$REPO/.context/working/.hook-counter"
    # track the vendor stub too, so it is not seen as uncommitted real code
    git -C "$REPO" add a.txt foo.sh .context/working/.hook-counter bin/fw
    git -C "$REPO" commit -q -m "base"
    BASE="$(git -C "$REPO" rev-parse HEAD)"

    # master diverges: a new file only on master
    echo "master only" > "$REPO/m.txt"
    git -C "$REPO" add m.txt
    git -C "$REPO" commit -q -m "master diverge"
}

teardown() {
    [ -n "$REPO" ] && rm -rf "$REPO" 2>/dev/null || true
}

# Make a divergent feature branch from BASE with a disjoint change (no conflict).
_mk_clean_feat() {
    git -C "$REPO" checkout -q -b feat "$BASE"
    echo "feat only" > "$REPO/f.txt"
    git -C "$REPO" add f.txt
    git -C "$REPO" commit -q -m "feat diverge"
}

# Make a divergent feature branch that conflicts with master on real code.
_mk_conflict_feat() {
    # master must also change foo.sh so it is changed on BOTH sides of BASE
    git -C "$REPO" checkout -q master
    echo "master version" > "$REPO/foo.sh"
    git -C "$REPO" commit -q -am "master edits foo.sh"
    git -C "$REPO" checkout -q -b feat "$BASE"
    echo "feat version" > "$REPO/foo.sh"
    git -C "$REPO" commit -q -am "feat edits foo.sh"
}

@test "run on master refuses (exit 3 — nothing to integrate)" {
    run bash -c "cd '$REPO' && git checkout -q master && python3 '$INTEGRATE' run master"
    [ "$status" -eq 3 ]
}

@test "dry-run prints plan and mutates nothing" {
    _mk_clean_feat
    local before; before="$(git -C "$REPO" rev-parse HEAD)"
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' run master --dry-run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN plan"* ]]
    # HEAD unchanged, no vendor sentinel
    [ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
    [ ! -e "$REPO/.vendor-ran" ]
}

@test "divergent branch + regenerable churn → merged, churn restored, vendored refreshed, exit 0" {
    _mk_clean_feat
    # dirty regenerable churn in the feat checkout
    echo "999" > "$REPO/.context/working/.hook-counter"
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' run master"
    [ "$status" -eq 0 ]
    # master's commit is now reachable from feat HEAD (merged in)
    run git -C "$REPO" merge-base --is-ancestor master HEAD
    [ "$status" -eq 0 ]
    # the regenerable churn was quiesced and restored
    [ "$(cat "$REPO/.context/working/.hook-counter")" = "999" ]
    # vendor-refresh fired
    [ -e "$REPO/.vendor-ran" ]
}

@test "both-sided real code conflict → clean refuse (exit 2, target untouched)" {
    _mk_conflict_feat
    local before; before="$(git -C "$REPO" rev-parse HEAD)"
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' run master"
    [ "$status" -eq 2 ]
    # feat HEAD unchanged — no merge attempted past preflight
    [ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
    # master is NOT an ancestor of feat (nothing merged)
    run git -C "$REPO" merge-base --is-ancestor master HEAD
    [ "$status" -ne 0 ]
    [ ! -e "$REPO/.vendor-ran" ]
}

@test "uncommitted real code in worktree → refuse (exit 2)" {
    _mk_clean_feat
    echo "uncommitted edit" >> "$REPO/foo.sh"   # real code, not regenerable
    local before; before="$(git -C "$REPO" rev-parse HEAD)"
    run bash -c "cd '$REPO' && python3 '$INTEGRATE' run master"
    [ "$status" -eq 2 ]
    [ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
}
