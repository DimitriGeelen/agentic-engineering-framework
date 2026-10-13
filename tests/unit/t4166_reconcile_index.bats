#!/usr/bin/env bats
# T-4166 / G-114: reconcile armed stale index entries (index only).

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    MOD="$ROOT/lib/index_reconcile.py"
    R="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$R" && cd "$R"
    git init -q -b main .
    git config user.email t@t && git config user.name t
    mkdir -p .tasks/active .tasks/completed .context/episodic
    printf 'status: started-work\nDecision: DEFER\n' > .tasks/active/T-1-a.md
    printf 'status: started-work\nbody\n' > .tasks/active/T-2-b.md
    printf 'ep old\n' > .context/episodic/T-9.yaml
    git add -A && git commit -qm "T-1: base"
    # Decision commit through a scratch index (the T-2708 shape); real index left stale.
    export GIT_INDEX_FILE="$BATS_TEST_TMPDIR/scratch.idx"
    git read-tree HEAD
    git mv .tasks/active/T-1-a.md .tasks/completed/T-1-a.md
    printf 'status: work-completed\nDecision: GO\n' > .tasks/completed/T-1-a.md
    printf 'ep new\n' > .context/episodic/T-1.yaml
    git add .tasks/completed/T-1-a.md .context/episodic/T-1.yaml
    git rm -q --cached .context/episodic/T-9.yaml
    git commit -qm "T-1: inception decision GO (via Watchtower)"
    unset GIT_INDEX_FILE
    rm -f "$BATS_TEST_TMPDIR/scratch.idx"
    # Worktree reflects the decision; the real index does not.
    rm -f .context/episodic/T-9.yaml
}

hashes() { find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha1sum; }

@test "detector finds the moved task, its twin deletion and the deleted episodic" {
    run python3 -I "$MOD" --repo "$R"
    [ "$status" -eq 2 ]
    [[ "$output" == *"ARMED old-version .tasks/active/T-1-a.md"* ]]
    [[ "$output" == *"ARMED move-undone .tasks/completed/T-1-a.md"* ]]
    [[ "$output" == *"ARMED episodic-deleted .context/episodic/T-1.yaml"* ]]
}

@test "stale index re-adding a removed episodic is armed (old version)" {
    run python3 -I "$MOD" --repo "$R"
    [ "$status" -eq 2 ]
    [[ "$output" == *"ARMED old-version .context/episodic/T-9.yaml"* ]]
}

@test "apply resets index to HEAD, worktree untouched, next commit keeps the decision" {
    before=$(hashes)
    run python3 -I "$MOD" --repo "$R" --apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESET"* ]]
    [ "$before" = "$(hashes)" ]
    run git diff --cached --name-only HEAD -- .tasks .context/episodic
    [ -z "$output" ]
    # ordinary commit of an unrelated change keeps the decision at HEAD
    echo x > other.txt && git add other.txt && git commit -qm "T-3: other"
    git show HEAD:.tasks/completed/T-1-a.md | grep -q "Decision: GO"
    [ -z "$(git ls-tree -r --name-only HEAD .tasks/active | grep T-1-a || true)" ]
    git cat-file -e HEAD:.context/episodic/T-1.yaml
}

@test "without the reconcile the next commit reverts the decision (control)" {
    echo x > other.txt && git add other.txt && git commit -qm "T-3: other"
    git show HEAD:.tasks/active/T-1-a.md | grep -q "Decision: DEFER"
}

@test "a user's genuinely new staged edit is not reset" {
    printf 'status: started-work\nbody EDITED\n' > .tasks/active/T-2-b.md
    git add .tasks/active/T-2-b.md
    run python3 -I "$MOD" --repo "$R" --apply
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-2-b"* ]]
    run git diff --cached --name-only HEAD -- .tasks/active/T-2-b.md
    [ "$output" = ".tasks/active/T-2-b.md" ]
}

@test "clean repo: exit 0, nothing reported" {
    python3 -I "$MOD" --repo "$R" --apply >/dev/null
    run python3 -I "$MOD" --repo "$R"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no armed"* ]]
}

@test "fw git reconcile-index is dry-run by default and --apply resets" {
    run env PROJECT_ROOT="$R" "$ROOT/bin/fw" git reconcile-index
    [ "$status" -eq 2 ]
    run git diff --cached --name-only HEAD -- .tasks
    [ -n "$output" ]
    run env PROJECT_ROOT="$R" "$ROOT/bin/fw" git reconcile-index --apply
    [ "$status" -eq 0 ]
    run git diff --cached --name-only HEAD -- .tasks .context/episodic
    [ -z "$output" ]
}
