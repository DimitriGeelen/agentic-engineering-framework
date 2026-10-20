#!/usr/bin/env bats
# T-2961 (T-2925 GO): the pre-push VERSION stamp composed <major.minor>.<commits>
# from `git describe`, dropping the tag's patch. The third field was a distance
# that reset at every tag: v1.8.9 + 92 commits stamped 1.8.92, which sorts
# "newer" than v1.8.10. The stamp now writes T-4055's grammar, X.Y.Z+N.gSHA,
# the same string bin/fw _derive_version produces.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo base > "$REPO/f"; git -C "$REPO" add f; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.8.9
    HOOKS="$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

# Run the hook's stamp block exactly as shipped (same extraction as t3821).
_run_stamp_block() {
    sed -n '/^# Stamp VERSION file from git describe/,/^    echo "VERSION stamped: \$_stamped"/p' "$HOOKS" > "$TEST_TEMP_DIR/stamp.sh"
    echo fi >> "$TEST_TEMP_DIR/stamp.sh"
    run bash -c "cd '$REPO' && PROJECT_ROOT='$REPO' bash '$TEST_TEMP_DIR/stamp.sh'" 2>&1
}

_commits() {
    local i
    for i in $(seq 1 "$1"); do
        echo "$i" > "$REPO/w$i"; git -C "$REPO" add "w$i"; git -C "$REPO" commit -qm "w$i"
    done
}

@test "stamp keeps the tag's patch: v1.8.9 + 12 commits -> 1.8.9+12.g<sha>" {
    _commits 12
    sha=$(git -C "$REPO" rev-parse --short HEAD)
    _run_stamp_block
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/VERSION")" = "1.8.9+12.g$sha" ]
    [[ "$output" =~ "VERSION stamped: 1.8.9+12.g" ]]
}

@test "stamped value never sorts above the next release (the 1.8.92 > 1.8.10 class)" {
    _commits 12
    _run_stamp_block
    [ "$status" -eq 0 ]
    newest=$(printf '%s\n' "$(cat "$REPO/VERSION")" 1.8.10 | sort -V | tail -1)
    [ "$newest" = "1.8.10" ]
}

@test "on an exact tag the stamp is the bare version" {
    _run_stamp_block
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/VERSION")" = "1.8.9" ]
}

@test "stamp matches bin/fw _derive_version's grammar (two copies, one regex)" {
    re='^([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)-(g[0-9a-f]+)$'
    grep -qF "$re" "$FRAMEWORK_ROOT/bin/fw"
    grep -qF "$re" "$HOOKS"
}
