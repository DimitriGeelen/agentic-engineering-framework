#!/usr/bin/env bats
# T-4379 (T-4398 prevention) — the pre-commit hook runs the bats dead-negation
# lint on STAGED tests/**/*.bats, so a dead `!` assertion is refused at the commit
# that writes it instead of a push later.
#
# Hermetic: hooks are installed into a fixture repo (PROJECT_ROOT, not cwd, picks
# the hooks directory — see tests/unit/hook_version_marker_parity.bats), whose
# .framework.yaml points framework_path at this checkout so every scanner the hook
# runs before the new block is present. The hook is then run directly; no commit
# is made, so the commit-msg hook is out of scope here.

setup() {
    FW_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    FX="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FX/tests/unit" "$FX/tools"
    git -C "$FX" init -q
    git -C "$FX" config user.email "t4379@localhost"
    git -C "$FX" config user.name "T-4379 fixture"
    printf 'framework_path: %s\n' "$FW_ROOT" > "$FX/.framework.yaml"
    cp "$FW_ROOT/tools/bats-dead-negation-lint.py" "$FX/tools/"
    export PROJECT_ROOT="$FX"
    run bash "$FW_ROOT/agents/git/git.sh" install-hooks
    [ "$status" -eq 0 ]
    [ -f "$FX/.git/hooks/pre-commit" ]
}

_write_test() {
    # BATSTEST, not @test: bats rewrites @test lines even inside this file's
    # quoted heredocs (tests/lint/bats-dead-negation.bats).
    sed 's/^BATSTEST /@test /' > "$FX/$1"
}

_precommit() {
    run bash -c "cd '$FX' && PROJECT_ROOT='$FX' .git/hooks/pre-commit"
}

@test "a staged bats test with a dead negation is refused" {
    _write_test tests/unit/dead.bats <<'EOF'
BATSTEST "x" {
    ! grep -q nope file
    [ 1 -eq 1 ]
}
EOF
    git -C "$FX" add tests/unit/dead.bats
    _precommit
    [ "$status" -ne 0 ]
    [[ "$output" == *"dead negation in a staged bats test"* ]]
    [[ "$output" == *"tests/unit/dead.bats:2"* ]]
}

@test "a staged bats test with only live negations passes" {
    _write_test tests/unit/live.bats <<'EOF'
BATSTEST "x" {
    ! grep -q nope file || false
    [ 1 -eq 1 ]
    ! grep -q nope file
}
EOF
    git -C "$FX" add tests/unit/live.bats
    _precommit
    [ "$status" -eq 0 ]
    [[ "$output" != *"dead negation"* ]]
}

@test "the STAGED blob is scanned, not the worktree file" {
    # Stage a dead negation, then fix the worktree copy without staging the fix:
    # the commit would still carry the dead line, so it must still be refused.
    _write_test tests/unit/staged.bats <<'EOF'
BATSTEST "x" {
    ! grep -q nope file
    [ 1 -eq 1 ]
}
EOF
    git -C "$FX" add tests/unit/staged.bats
    sed -i 's/^    ! grep -q nope file$/    ! grep -q nope file || false/' "$FX/tests/unit/staged.bats"
    _precommit
    [ "$status" -ne 0 ]
    [[ "$output" == *"dead negation"* ]]
}

@test "a commit with no staged bats test is untouched" {
    echo hi > "$FX/README"
    _write_test tests/unit/unstaged.bats <<'EOF'
BATSTEST "x" {
    ! grep -q nope file
    [ 1 -eq 1 ]
}
EOF
    git -C "$FX" add README
    _precommit
    [ "$status" -eq 0 ]
    [[ "$output" != *"dead negation"* ]]
}
