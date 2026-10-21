#!/usr/bin/env bats
# T-4528: commit-msg refuses a commit that deletes files last committed by a
# DIFFERENT task unless the message names that task. Origin: 290e149d6 (T-3866)
# committed from a scratch index built before eac91df2f (T-4520) and deleted
# T-4520's six new files.
#
# END-TO-END: installs the real hooks into a fixture repo and runs real
# `git commit`s, two "workers" sharing one checkout.

load ../test_helper

setup() {
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
          GIT_COMMON_DIR GIT_PREFIX GIT_REFLOG_ACTION FW_ALLOW_FOREIGN_DELETE
    REPO="$BATS_TEST_TMPDIR/consumer"
    mkdir -p "$REPO/.tasks/active" "$REPO/.tasks/completed" "$REPO/.context/working" "$REPO/src"
    git -C "$REPO" init -q -b feature
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    printf 'framework_path: %s\n' "$FRAMEWORK_ROOT" > "$REPO/.framework.yaml"
    echo base > "$REPO/src/base.txt"
    git -C "$REPO" add -A >/dev/null
    git -C "$REPO" commit -q --no-verify -m "T-001: base"
    ( cd "$REPO" && env -u CLAUDE_PROJECT_DIR -u PROJECT_ROOT -u TASKS_DIR \
        -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u _FW_PATHS_LOADED \
        "$FRAMEWORK_ROOT/bin/fw" git install-hooks >/dev/null 2>&1 )
    [ -f "$REPO/.git/hooks/commit-msg" ]
    grep -q foreign-delete-guard "$REPO/.git/hooks/commit-msg"
    SCRATCH="$REPO/.context/working/b-index"
}

teardown() { :; }   # BATS_TEST_TMPDIR is cleaned by bats itself

# Worker A (T-002) commits two new files with the --only form.
_worker_a_commits() {
    echo a1 > "$REPO/src/a1.txt"
    echo "status: started-work" > "$REPO/.tasks/active/T-002-a.md"
    git -C "$REPO" add src/a1.txt .tasks/active/T-002-a.md
    git -C "$REPO" commit -q --no-verify -m "T-002: add a" -- src/a1.txt .tasks/active/T-002-a.md
}

# Worker B (T-003) commits from a scratch index built BEFORE A's commit.
_worker_b_commits() {
    echo b > "$REPO/src/b.txt"
    run env GIT_INDEX_FILE="$SCRATCH" git -C "$REPO" add src/b.txt
    [ "$status" -eq 0 ]
    run env GIT_INDEX_FILE="$SCRATCH" "$@" git -C "$REPO" commit -m "$MSG"
}

@test "two workers: a stale scratch index that deletes the other task's new files is refused" {
    GIT_INDEX_FILE="$SCRATCH" git -C "$REPO" read-tree HEAD
    _worker_a_commits
    MSG="T-003: mine"
    _worker_b_commits
    [ "$status" -ne 0 ]
    [[ "$output" == *"deletes files last committed by another task"* ]]
    [[ "$output" == *"src/a1.txt  (last committed by T-002)"* ]]
    [[ "$output" == *".tasks/active/T-002-a.md"* ]]
    [[ "$output" == *"FW_ALLOW_FOREIGN_DELETE=1"* ]]
    # nothing was committed: A's files are still in HEAD
    git -C "$REPO" cat-file -e HEAD:src/a1.txt
    [ "$(git -C "$REPO" log -1 --format=%s)" = "T-002: add a" ]
}

@test "two workers: a scratch index rebuilt after the other commit passes" {
    _worker_a_commits
    GIT_INDEX_FILE="$SCRATCH" git -C "$REPO" read-tree HEAD
    MSG="T-003: mine"
    _worker_b_commits
    [ "$status" -eq 0 ]
    git -C "$REPO" cat-file -e HEAD:src/a1.txt
    git -C "$REPO" cat-file -e HEAD:src/b.txt
}

@test "a task deleting its own files passes" {
    _worker_a_commits
    git -C "$REPO" rm -q src/a1.txt
    run git -C "$REPO" commit -m "T-002: drop a1"
    [ "$status" -eq 0 ]
    ! git -C "$REPO" cat-file -e HEAD:src/a1.txt 2>/dev/null || false
}

@test "deleting another task's file passes when the message names that task" {
    _worker_a_commits
    git -C "$REPO" rm -q src/a1.txt
    run git -C "$REPO" commit -m "T-003: remove a1 (superseded, was T-002's)"
    [ "$status" -eq 0 ]
}

@test "deleting another task's file without naming it is refused on a plain commit too" {
    _worker_a_commits
    git -C "$REPO" rm -q src/a1.txt
    run git -C "$REPO" commit -m "T-003: cleanup"
    [ "$status" -ne 0 ]
    [[ "$output" == *"src/a1.txt  (last committed by T-002)"* ]]
}

@test "FW_ALLOW_FOREIGN_DELETE=1 lets it through and logs a Tier-2 bypass" {
    GIT_INDEX_FILE="$SCRATCH" git -C "$REPO" read-tree HEAD
    _worker_a_commits
    MSG="T-003: mine"
    _worker_b_commits FW_ALLOW_FOREIGN_DELETE=1
    [ "$status" -eq 0 ]
    [[ "$output" == *"bypassed via FW_ALLOW_FOREIGN_DELETE=1"* ]]
    grep -q "foreign-delete-guard (T-4528)" "$REPO/.context/working/.gate-bypass-log.yaml"
    grep -q "src/a1.txt (T-002)" "$REPO/.context/working/.gate-bypass-log.yaml"
}

@test "moving a task file active -> completed is not a deletion" {
    _worker_a_commits
    git -C "$REPO" mv .tasks/active/T-002-a.md .tasks/completed/T-002-a.md
    printf 'status: work-completed\nmany\nmore\nlines\nchanged\n' > "$REPO/.tasks/completed/T-002-a.md"
    git -C "$REPO" add -A .tasks
    run git -C "$REPO" commit -m "T-003: handover sweep"
    [ "$status" -eq 0 ]
}

@test "a file whose last commit names no task is not attributable and passes" {
    echo x > "$REPO/src/untagged.txt"
    git -C "$REPO" add src/untagged.txt
    git -C "$REPO" commit -q --no-verify -m "untagged import"
    git -C "$REPO" rm -q src/untagged.txt
    run git -C "$REPO" commit -m "T-003: drop untagged"
    [ "$status" -eq 0 ]
}

# T-4563: fw upgrade removes vendored files whose last commit is the PREVIOUS
# upgrade's task; a commit staging only .agentic-framework/ is a re-vendor.
_previous_upgrade_vendors() {
    mkdir -p "$REPO/.agentic-framework/lib"
    echo old > "$REPO/.agentic-framework/lib/dropped.sh"
    echo v1 > "$REPO/.agentic-framework/VERSION"
    git -C "$REPO" add .agentic-framework
    git -C "$REPO" commit -q --no-verify -m "T-010: fw upgrade to v1" -- .agentic-framework
}

@test "T-4563: a pure re-vendor commit deleting the previous upgrade's vendored file passes" {
    _previous_upgrade_vendors
    git -C "$REPO" rm -q .agentic-framework/lib/dropped.sh
    echo v2 > "$REPO/.agentic-framework/VERSION"
    git -C "$REPO" add .agentic-framework
    run git -C "$REPO" commit -m "T-011: re-vendor v2"
    [ "$status" -eq 0 ]
    ! git -C "$REPO" cat-file -e HEAD:.agentic-framework/lib/dropped.sh 2>/dev/null || false
}

@test "T-4563: a mixed commit deleting another task's file outside the vendored dir is still refused" {
    _previous_upgrade_vendors
    _worker_a_commits
    git -C "$REPO" rm -q .agentic-framework/lib/dropped.sh src/a1.txt
    run git -C "$REPO" commit -m "T-011: re-vendor v2"
    [ "$status" -ne 0 ]
    [[ "$output" == *"src/a1.txt  (last committed by T-002)"* ]]
    [[ "$output" == *"commit .agentic-framework/ on its own"* ]]
    git -C "$REPO" cat-file -e HEAD:src/a1.txt
}
