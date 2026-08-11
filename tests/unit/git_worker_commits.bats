#!/usr/bin/env bats
# Unit tests for agents/git/lib/worker-commits.sh (T-2917)
#
# Pins BOTH directions: a worker commit (GIT_AUTHOR_EMAIL matching the
# dispatch+<id>@aef.local shape minted by lib/worker_identity.py /
# lib/git-identity.sh:fw_worker_git_identity_env) is attributed to the worker
# identity and surfaced by `worker-commits`; an operator commit in the SAME
# repo is not — so the fix cannot pass by relabelling everything as a worker.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Ambient GIT_AUTHOR_*/GIT_COMMITTER_* may already be set in the calling
    # shell (e.g. this very test run is itself inside a dispatch-spawned
    # worker) — unset before the "operator" fixture commit so it exercises
    # git config identity, not whatever identity spawned this test run.
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

    cd "$PROJECT_ROOT"
    git init -q
    git config user.email "operator@example.com"
    git config user.name "The Operator"

    echo "a" > file.txt && git add . && git commit -q -m "T-2917: operator commit, typed by hand"
    OPERATOR_SHA="$(git rev-parse --short=8 HEAD)"
    export OPERATOR_SHA

    echo "b" > file.txt
    GIT_AUTHOR_NAME="fw worker (resolver-loop)" \
    GIT_AUTHOR_EMAIL="dispatch+a398504a@aef.local" \
    GIT_COMMITTER_NAME="fw worker (resolver-loop)" \
    GIT_COMMITTER_EMAIL="dispatch+a398504a@aef.local" \
        git add . && \
    GIT_AUTHOR_NAME="fw worker (resolver-loop)" \
    GIT_AUTHOR_EMAIL="dispatch+a398504a@aef.local" \
    GIT_COMMITTER_NAME="fw worker (resolver-loop)" \
    GIT_COMMITTER_EMAIL="dispatch+a398504a@aef.local" \
        git commit -q -m "T-2917: worker commit, dispatched by the resolver loop"
    WORKER_SHA="$(git rev-parse --short=8 HEAD)"
    export WORKER_SHA

    source "$FRAMEWORK_ROOT/agents/git/lib/common.sh"
    source "$FRAMEWORK_ROOT/agents/git/lib/worker-commits.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "do_worker_commits: surfaces the worker commit" {
    run do_worker_commits --days 3650
    [ "$status" -eq 0 ]
    [[ "$output" == *"$WORKER_SHA"* ]]
    [[ "$output" == *"resolver-loop"* ]]
    [[ "$output" == *"a398504a"* ]]
}

@test "do_worker_commits: does NOT surface the operator commit" {
    run do_worker_commits --days 3650
    [ "$status" -eq 0 ]
    [[ "$output" != *"$OPERATOR_SHA"* ]]
    [[ "$output" != *"operator@example.com"* ]]
    [[ "$output" != *"The Operator"* ]]
}

@test "do_worker_commits: --json emits valid JSON with only the worker commit" {
    run do_worker_commits --days 3650 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
rows = json.load(sys.stdin)
assert len(rows) == 1, rows
assert rows[0]['mechanism'] == 'resolver-loop', rows[0]
assert rows[0]['dispatch_id_prefix'] == 'a398504a', rows[0]
"
}

@test "do_worker_commits: --task filters to matching task ref" {
    run do_worker_commits --days 3650 --task T-2917
    [ "$status" -eq 0 ]
    [[ "$output" == *"$WORKER_SHA"* ]]
}

@test "do_worker_commits: --task with nonexistent ID returns none" {
    run do_worker_commits --days 3650 --task T-9999
    [ "$status" -eq 0 ]
    [[ "$output" == *"None"* ]]
    [[ "$output" != *"$WORKER_SHA"* ]]
}

@test "do_worker_commits: --days window excludes commits outside it" {
    # --days 0 is NOT a reliable "exclude everything" probe: git's --since
    # floor is effectively "now", and a fixture commit made in the same
    # second as the query still falls inside it — same-second flakiness,
    # not a real window boundary. Use an actually-old commit instead — and
    # build it as its own repo with the old commit FIRST in the DAG (i.e.
    # chronologically monotonic history). Appending an old-dated commit as
    # the new HEAD on top of the shared "now" fixture inverts commit-time
    # vs. DAG order, and git log's default (non --date-order) walk prunes
    # the whole traversal at the first out-of-order commit it meets —
    # silently emptying the result for reasons unrelated to --since itself.
    local win_dir="$TEST_TEMP_DIR/window-repo"
    mkdir -p "$win_dir"
    cd "$win_dir"
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
    git init -q
    git config user.email "operator@example.com"
    git config user.name "The Operator"

    local old_date
    old_date="$(date -u -d '400 days ago' '+%Y-%m-%dT%H:%M:%S+00:00')"
    echo "old" > old.txt
    GIT_AUTHOR_NAME="fw worker (resolver-loop)" \
    GIT_AUTHOR_EMAIL="dispatch+deadbeef@aef.local" \
    GIT_COMMITTER_NAME="fw worker (resolver-loop)" \
    GIT_COMMITTER_EMAIL="dispatch+deadbeef@aef.local" \
    GIT_AUTHOR_DATE="$old_date" \
    GIT_COMMITTER_DATE="$old_date" \
        git add . && \
    GIT_AUTHOR_NAME="fw worker (resolver-loop)" \
    GIT_AUTHOR_EMAIL="dispatch+deadbeef@aef.local" \
    GIT_COMMITTER_NAME="fw worker (resolver-loop)" \
    GIT_COMMITTER_EMAIL="dispatch+deadbeef@aef.local" \
    GIT_AUTHOR_DATE="$old_date" \
    GIT_COMMITTER_DATE="$old_date" \
        git commit -q -m "T-2917: old worker commit, outside the window"

    echo "recent" > recent.txt
    GIT_AUTHOR_NAME="fw worker (resolver-loop)" \
    GIT_AUTHOR_EMAIL="dispatch+cafef00d@aef.local" \
    GIT_COMMITTER_NAME="fw worker (resolver-loop)" \
    GIT_COMMITTER_EMAIL="dispatch+cafef00d@aef.local" \
        git add . && \
    GIT_AUTHOR_NAME="fw worker (resolver-loop)" \
    GIT_AUTHOR_EMAIL="dispatch+cafef00d@aef.local" \
    GIT_COMMITTER_NAME="fw worker (resolver-loop)" \
    GIT_COMMITTER_EMAIL="dispatch+cafef00d@aef.local" \
        git commit -q -m "T-2917: recent worker commit, inside the window"

    local saved_root="$PROJECT_ROOT"
    export PROJECT_ROOT="$win_dir"
    run do_worker_commits --days 7
    export PROJECT_ROOT="$saved_root"

    [ "$status" -eq 0 ]
    [[ "$output" == *"cafef00d"* ]]
    [[ "$output" != *"deadbeef"* ]]
}

@test "do_worker_commits: no worker commits in window prints None, not an error" {
    # A fresh repo with only operator commits and zero worker commits ever —
    # independent of any timing window, since none exist to include.
    local none_dir="$TEST_TEMP_DIR/none-repo"
    mkdir -p "$none_dir"
    cd "$none_dir"
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
    git init -q
    git config user.email "second-operator@example.com"
    git config user.name "Second Operator"
    echo "c" > file.txt && git add . && git commit -q -m "T-2917: another operator commit"

    local saved_root="$PROJECT_ROOT"
    export PROJECT_ROOT="$none_dir"
    run do_worker_commits --days 3650
    export PROJECT_ROOT="$saved_root"

    [ "$status" -eq 0 ]
    [[ "$output" == *"None"* ]]
}

@test "show_worker_commits_help: outputs usage text" {
    run show_worker_commits_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Worker Commits"* ]]
    [[ "$output" == *"--days"* ]]
    [[ "$output" == *"--task"* ]]
    [[ "$output" == *"--json"* ]]
}

@test "do_worker_commits: -h shows help and exits 0" {
    run do_worker_commits -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Worker Commits"* ]]
}

@test "do_worker_commits: unknown option exits with error" {
    run do_worker_commits --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option: --bogus"* ]]
}
