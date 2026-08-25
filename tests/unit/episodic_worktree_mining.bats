#!/usr/bin/env bats
# T-3129 — episodic git mining in a LINKED GIT WORKTREE, and the shape of a
# skipped measurement.
#
# Two independent defects, two independent controls:
#
#   AC1/AC2 — the mining guard was `[ -d "$PROJECT_ROOT/.git" ]`. In a linked
#     worktree `.git` is a regular FILE holding a `gitdir:` pointer, so the test
#     was false and every mine_git_* call was skipped, even though the `git -C`
#     invocations inside the block work fine from a worktree. This class is
#     STRUCTURALLY INVISIBLE from a normal checkout: run the rest of the suite
#     from a plain clone and it passes. The control below therefore builds a
#     synthetic repo in a tmpdir and `git worktree add`s a linked worktree,
#     because that is the only shape in which the bug exists.
#
#   AC3 — a skipped measurement wrote its INITIALISED value (0) as a result.
#     `commits: 0` reads as "measured, answer none"; the fix emits `null` so a
#     reader can tell "not measured" apart from "measured, none". This is a
#     separate assertion from the guard: fixing the guard alone leaves the
#     silent-failure shape intact for every other reason mining can fail.
#
# L-599: everything here is a purpose-built fixture. Nothing is pinned to the
# live .context/episodic corpus, to any currently-failing task id, or to the
# 577 false zeros measured on this repo — these controls must still pass after
# that corpus is backfilled.

load ../test_helper

# Build a synthetic git repo with a known number of T-4242 commits, plus the
# task file the generator reads. Echoes nothing; sets up $1 as the repo root.
_seed_fixture_repo() {
    local root="$1"
    mkdir -p "$root"
    git -C "$root" init -q
    git -C "$root" config user.email "fixture@t3129.test"
    git -C "$root" config user.name "T-3129 Fixture"
    git -C "$root" config commit.gpgsign false

    # Three commits carrying the task id, with real content churn so --numstat
    # has something to add up.
    local n
    for n in 1 2 3; do
        printf 'line %s\nline %s-b\n' "$n" "$n" > "$root/file-$n.txt"
        git -C "$root" add "file-$n.txt"
        git -C "$root" commit -q --no-verify -m "T-4242: fixture commit $n"
    done
    # One unrelated commit that must NOT be counted.
    echo noise > "$root/unrelated.txt"
    git -C "$root" add unrelated.txt
    git -C "$root" commit -q --no-verify -m "T-9999: unrelated"
}

# Write the fixture task file into an already-existing project tree.
_seed_task_file() {
    local root="$1"
    mkdir -p "$root/.tasks/completed"
    cat > "$root/.tasks/completed/T-4242-fixture.md" <<'EOF'
---
id: T-4242
name: "Fixture task for T-3129 worktree mining control"
description: "Synthetic fixture — not pinned to the live corpus (L-599)"
status: work-completed
workflow_type: build
owner: agent
created: 2026-01-01T00:00:00Z
last_update: 2026-01-02T00:00:00Z
tags: []
---

# T-4242: Fixture

## Acceptance Criteria

- [x] Fixture AC one
- [ ] Fixture AC two

## Verification

true
EOF
}

# Run do_generate_episodic for T-4242 with PROJECT_ROOT pointed at $1.
# Runs in a subshell so the sourced library never leaks between tests.
_generate_from() {
    local root="$1"
    (
        set +e
        export PROJECT_ROOT="$root"
        guard_project_root
        export CONTEXT_DIR="$root/.context"
        export TASKS_DIR="$root/.tasks"
        export FRAMEWORK_ROOT
        RED='' GREEN='' YELLOW='' CYAN='' NC=''
        ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/episodic"; }
        mkdir -p "$CONTEXT_DIR/episodic"
        source "$FRAMEWORK_ROOT/lib/compat.sh"
        source "$FRAMEWORK_ROOT/lib/tasks.sh"
        source "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
        do_generate_episodic T-4242
    )
}

# Read one metrics key out of the generated episodic. Echoes the repr of the
# value, or the literal string ABSENT when the key is not present at all.
_metric() {
    local episodic="$1" key="$2"
    python3 - "$episodic" "$key" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
m = (d or {}).get('metrics') or {}
print('ABSENT' if sys.argv[2] not in m else repr(m[sys.argv[2]]))
PY
}

# ---------------------------------------------------------------------------
# AC2 — the linked-worktree control. This is the one that must fail pre-change.
# ---------------------------------------------------------------------------

@test "T-3129 AC2: episodic generated FROM A LINKED WORKTREE mines commits" {
    local main="$TEST_TEMP_DIR/upstream"
    local wt="$TEST_TEMP_DIR/linked-worktree"
    _seed_fixture_repo "$main"
    git -C "$main" worktree add -q -b t3129-fixture-branch "$wt"

    # This is the shape under test: .git is a FILE, not a directory.
    [ -f "$wt/.git" ]
    [ ! -d "$wt/.git" ]

    _seed_task_file "$wt"
    run _generate_from "$wt"
    [ "$status" -eq 0 ]

    local ep="$wt/.context/episodic/T-4242.yaml"
    [ -f "$ep" ]
    # 3 commits carry T-4242; the T-9999 commit must not be counted.
    [ "$(_metric "$ep" commits)" = "3" ]
    [ "$(_metric "$ep" git_mining)" = "'ok'" ]
}

@test "T-3129 AC2: linked-worktree episodic mines files/lines, not just count" {
    local main="$TEST_TEMP_DIR/upstream2"
    local wt="$TEST_TEMP_DIR/linked-worktree2"
    _seed_fixture_repo "$main"
    git -C "$main" worktree add -q -b t3129-fixture-branch2 "$wt"
    _seed_task_file "$wt"
    run _generate_from "$wt"
    [ "$status" -eq 0 ]

    local ep="$wt/.context/episodic/T-4242.yaml"
    # 3 files touched, 2 lines added each.
    [ "$(_metric "$ep" files_changed)" = "3" ]
    [ "$(_metric "$ep" lines_added)" = "6" ]
    grep -q "T-4242: fixture commit 1" "$ep"
}

@test "T-3129 AC2: linked-worktree episodic mines the git timeline and artifacts" {
    local main="$TEST_TEMP_DIR/upstream3"
    local wt="$TEST_TEMP_DIR/linked-worktree3"
    _seed_fixture_repo "$main"
    git -C "$main" worktree add -q -b t3129-fixture-branch3 "$wt"
    _seed_task_file "$wt"
    run _generate_from "$wt"
    [ "$status" -eq 0 ]

    local ep="$wt/.context/episodic/T-4242.yaml"
    # Timeline and artifact mining live in the same skipped block as the counters.
    run grep -q "No git timeline available" "$ep"
    [ "$status" -ne 0 ]
    grep -q "file-2.txt" "$ep"
}

# ---------------------------------------------------------------------------
# AC1 — the same generator must still work in an ordinary (non-worktree)
# checkout. The reachability test has to be true in BOTH shapes, so this is the
# regression side of the guard change.
# ---------------------------------------------------------------------------

@test "T-3129 AC1: ordinary checkout still mines commits after the guard change" {
    local main="$TEST_TEMP_DIR/plain"
    _seed_fixture_repo "$main"
    [ -d "$main/.git" ]
    _seed_task_file "$main"
    run _generate_from "$main"
    [ "$status" -eq 0 ]
    [ "$(_metric "$main/.context/episodic/T-4242.yaml" commits)" = "3" ]
}

# ---------------------------------------------------------------------------
# AC3 — a skipped measurement must be absent/null, never 0.
# ---------------------------------------------------------------------------

@test "T-3129 AC3: unreachable git emits null metrics, not zeros" {
    # No git repo anywhere above this tree: mining genuinely cannot run.
    local root="$TEST_TEMP_DIR/not-a-repo/project"
    mkdir -p "$root"
    _seed_task_file "$root"

    # Neutralise any enclosing repo (TMPDIR is not normally under one, but do
    # not depend on that) so `rev-parse --is-inside-work-tree` really fails.
    git -C "$TEST_TEMP_DIR/not-a-repo" init -q
    rm -rf "$TEST_TEMP_DIR/not-a-repo/.git"
    export GIT_CEILING_DIRECTORIES="$TEST_TEMP_DIR/not-a-repo"

    run _generate_from "$root"
    [ "$status" -eq 0 ]

    local ep="$root/.context/episodic/T-4242.yaml"
    [ -f "$ep" ]
    local v
    for v in commits files_changed lines_added lines_removed; do
        local got
        got="$(_metric "$ep" "$v")"
        # The assertion that matters: NOT the initialised zero.
        [ "$got" != "0" ]
        [ "$got" = "None" ] || [ "$got" = "ABSENT" ]
    done
    [ "$(_metric "$ep" git_mining)" = "'skipped'" ]
    # wall_clock_minutes is frontmatter-derived and IS measured — the null must
    # be scoped to the git-derived counters, not smeared across the block.
    [ "$(_metric "$ep" wall_clock_minutes)" != "None" ]
}

@test "T-3129 AC3: skipped mining does not print zeros as counted output" {
    local root="$TEST_TEMP_DIR/not-a-repo-b/project"
    mkdir -p "$root"
    _seed_task_file "$root"
    export GIT_CEILING_DIRECTORIES="$TEST_TEMP_DIR/not-a-repo-b"

    run _generate_from "$root"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not measured"* ]]
    [[ "$output" != *"Commits: 0"* ]]
}

@test "T-3129 AC3: emitted episodic is still valid YAML in the skipped case" {
    local root="$TEST_TEMP_DIR/not-a-repo-c/project"
    mkdir -p "$root"
    _seed_task_file "$root"
    export GIT_CEILING_DIRECTORIES="$TEST_TEMP_DIR/not-a-repo-c"
    run _generate_from "$root"
    [ "$status" -eq 0 ]
    python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" \
        "$root/.context/episodic/T-4242.yaml"
}
