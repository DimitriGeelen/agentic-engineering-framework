#!/usr/bin/env bats
# T-3697: operator-facing guidance must never tell agents to land a worktree on
# master. Release-train (CLAUDE.md §Release-Train Branch Model, T-3185): worktrees
# land on bleeding-edge; master only fast-forwards at release.

setup() {
    cd "$BATS_TEST_DIRNAME/../.." || return 1
}

@test "no guidance in lib/ or agents/ names master as the integrate target" {
    run grep -rnE 'integrate run master' lib agents --include='*.sh' --include='*.py'
    echo "$output"
    [ "$status" -eq 1 ]
}

@test "worktree governance block does not tell agents to edit on master" {
    run grep -nE 'edit on master' agents/context/check-worktree-governance-write.sh
    echo "$output"
    [ "$status" -eq 1 ]
}

@test "control: guidance names bleeding-edge as the integrate target" {
    run grep -c 'integrate run bleeding-edge' lib/upgrade.sh agents/context/check-worktree-governance-write.sh agents/git/lib/worktree-corpus-guard.sh
    echo "$output"
    [[ "$output" != *":0"* ]]
}
