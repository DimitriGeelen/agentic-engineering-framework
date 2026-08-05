#!/usr/bin/env bats
# T-2812: `fw git install-hooks` resolved hooks_dir by string-concatenating
# "$PROJECT_ROOT/.git/hooks" — correct only when .git is a directory sitting
# directly at PROJECT_ROOT. Wrong for a project nested inside an enclosing
# repo (fw init deliberately skips `git init` there — lib/init.sh:140), a
# worktree (.git is a file), and a submodule. This suite pins the fix:
# resolve via `git rev-parse --git-path hooks` instead.
#
# Invokes agents/git/git.sh directly (not `fw git`) with PROJECT_ROOT
# exported per-scenario, per the L-271 bats pattern.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TEST_TMP="$(mktemp -d)"
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

run_install_hooks() {
    PROJECT_ROOT="$1" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks
}

# --- Control case: plain repo, .git owned by PROJECT_ROOT (AC3) ---------

@test "plain repo: all four hooks land in PROJECT_ROOT/.git/hooks" {
    local proj="$TEST_TMP/proj"
    mkdir -p "$proj"
    git -C "$proj" init -q
    git -C "$proj" config user.email test@local
    git -C "$proj" config user.name test

    run run_install_hooks "$proj"
    [ "$status" -eq 0 ]

    for hook in commit-msg pre-commit post-commit pre-push; do
        [ -f "$proj/.git/hooks/$hook" ]
        [ -x "$proj/.git/hooks/$hook" ]
    done
}

# --- Nested project inside an enclosing repo (AC1, AC2, AC5) ------------

@test "nested project (no local .git): hooks land in the ENCLOSING repo, not silently dropped" {
    local outer="$TEST_TMP/outer"
    mkdir -p "$outer"
    git -C "$outer" init -q
    git -C "$outer" config user.email test@local
    git -C "$outer" config user.name test
    echo seed > "$outer/seed.txt"
    git -C "$outer" add seed.txt
    git -C "$outer" commit -q -m "T-0: seed"

    # fw init's actual behavior for this shape: no nested .git (lib/init.sh:140
    # skips `git init` when already inside a work tree).
    local proj="$outer/proj"
    mkdir -p "$proj"
    [ ! -d "$proj/.git" ]

    run run_install_hooks "$proj"
    [ "$status" -eq 0 ]

    # Must NOT create a spurious .git under proj/
    [ ! -d "$proj/.git" ]

    # Hooks must be installed where they will actually run: the enclosing repo.
    for hook in commit-msg pre-commit post-commit pre-push; do
        [ -f "$outer/.git/hooks/$hook" ]
        [ -x "$outer/.git/hooks/$hook" ]
    done
}

@test "nested project: a real commit in the enclosing repo is rejected for missing task reference" {
    local outer="$TEST_TMP/outer"
    mkdir -p "$outer"
    git -C "$outer" init -q
    git -C "$outer" config user.email test@local
    git -C "$outer" config user.name test
    echo seed > "$outer/seed.txt"
    git -C "$outer" add seed.txt
    git -C "$outer" commit -q -m "T-0: seed"

    local proj="$outer/proj"
    mkdir -p "$proj"
    run run_install_hooks "$proj"
    [ "$status" -eq 0 ]

    echo "change" > "$outer/proj/note.txt"
    git -C "$outer" add proj/note.txt
    run git -C "$outer" commit -q -m "untagged change with no task reference"
    [ "$status" -ne 0 ]
    [[ "$output" == *"task reference"* ]] || [[ "$output" == *"T-XXX"* ]] || [[ "$output" == *"No task"* ]]

    # Control: a properly-tagged commit on the same enclosing repo succeeds.
    run git -C "$outer" commit -q -m "T-9999: tagged change"
    [ "$status" -eq 0 ]
}

# --- Worktree (AC1 breadth: .git is a file, hooks live in the common dir) ---

@test "worktree: hooks resolve to the common dir, not a per-worktree path" {
    local main="$TEST_TMP/main"
    mkdir -p "$main"
    git -C "$main" init -q
    git -C "$main" config user.email test@local
    git -C "$main" config user.name test
    git -C "$main" commit -q --allow-empty -m "T-0: init"

    local wt="$TEST_TMP/wt"
    git -C "$main" worktree add -q "$wt" -b wt-branch >/dev/null 2>&1

    run run_install_hooks "$wt"
    [ "$status" -eq 0 ]

    for hook in commit-msg pre-commit post-commit pre-push; do
        [ -f "$main/.git/hooks/$hook" ]
        [ -x "$main/.git/hooks/$hook" ]
    done
}
