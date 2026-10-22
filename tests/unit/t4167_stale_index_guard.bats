#!/usr/bin/env bats
# T-4167: pre-commit refuses a commit whose staged .tasks/** or .context/episodic/**
# blob is an OLDER committed version of that path (a stale index entry that would
# silently revert later commits). Origin: ring20-manager T-2215 (msg 05d50237).
#
# END-TO-END: every test installs the real hooks into a fixture repo and runs a real
# `git commit`, so it proves git reaches the guard — not just that the predicate holds.

load ../test_helper

setup() {
    # Hermeticity (see t3511): inherited git/path vars re-point the fixture at the live repo.
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
          GIT_COMMON_DIR GIT_PREFIX GIT_REFLOG_ACTION FW_ALLOW_STALE_INDEX
    REPO="$BATS_TEST_TMPDIR/consumer"
    mkdir -p "$REPO/.tasks/active" "$REPO/.tasks/completed" "$REPO/.context/episodic" \
             "$REPO/.context/working"
    git -C "$REPO" init -q -b feature
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    printf 'framework_path: %s\n' "$FRAMEWORK_ROOT" > "$REPO/.framework.yaml"
    echo "status: captured" > "$REPO/.tasks/active/T-001-x.md"
    echo "summary: v1" > "$REPO/.context/episodic/T-001.yaml"
    echo v1 > "$REPO/src.txt"
    _commit_all "T-001: v1"
    echo "status: work-completed" > "$REPO/.tasks/active/T-001-x.md"
    echo "summary: v2" > "$REPO/.context/episodic/T-001.yaml"
    echo v2 > "$REPO/src.txt"
    _commit_all "T-001: v2"
    ( cd "$REPO" && env -u CLAUDE_PROJECT_DIR -u PROJECT_ROOT -u TASKS_DIR \
        -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u _FW_PATHS_LOADED \
        "$FRAMEWORK_ROOT/bin/fw" git install-hooks >/dev/null 2>&1 )
    [ -f "$REPO/.git/hooks/pre-commit" ]
}

teardown() { :; }   # BATS_TEST_TMPDIR is cleaned by bats itself

_commit_all() {
    git -C "$REPO" add -A >/dev/null
    git -C "$REPO" commit -q --no-verify -m "$1"
}

# Stage the v1 blob of $1 into the index without touching the working tree —
# exactly what a stale scratch index / un-refreshed entry looks like.
_stage_old() {
    local blob
    blob=$(git -C "$REPO" rev-parse "HEAD~1:$1")
    git -C "$REPO" update-index --cacheinfo "100644,$blob,$1"
}

_commit() { run git -C "$REPO" commit -m "T-001: $1"; }

@test "staged task file reverted to an older committed version is refused" {
    _stage_old .tasks/active/T-001-x.md
    _commit revert
    [ "$status" -ne 0 ]
    [[ "$output" == *"OLDER committed version"* ]]
    [[ "$output" == *".tasks/active/T-001-x.md"* ]]
    [[ "$output" == *"FW_ALLOW_STALE_INDEX=1"* ]]
}

@test "staged episodic reverted to an older committed version is refused" {
    _stage_old .context/episodic/T-001.yaml
    _commit revert
    [ "$status" -ne 0 ]
    [[ "$output" == *".context/episodic/T-001.yaml"* ]]
}

@test "a fresh edit of a task file is allowed" {
    echo "status: started-work" > "$REPO/.tasks/active/T-001-x.md"
    git -C "$REPO" add .tasks/active/T-001-x.md
    _commit fresh
    [ "$status" -eq 0 ]
}

@test "a new task file is allowed" {
    echo "status: captured" > "$REPO/.tasks/active/T-002-y.md"
    git -C "$REPO" add .tasks/active/T-002-y.md
    _commit new
    [ "$status" -eq 0 ]
}

@test "deleting a task file is allowed" {
    git -C "$REPO" rm -q .tasks/active/T-001-x.md
    _commit delete
    [ "$status" -eq 0 ]
}

@test "reverting a non-governed path is not this guard's business" {
    _stage_old src.txt
    _commit src
    [ "$status" -eq 0 ]
}

@test "scratch index via GIT_INDEX_FILE is the index that gets checked" {
    # The real index is clean; only the scratch index carries the stale blob.
    cp "$REPO/.git/index" "$BATS_TEST_TMPDIR/scratch-index"
    blob=$(git -C "$REPO" rev-parse "HEAD~1:.tasks/active/T-001-x.md")
    GIT_INDEX_FILE="$BATS_TEST_TMPDIR/scratch-index" \
        git -C "$REPO" update-index --cacheinfo "100644,$blob,.tasks/active/T-001-x.md"
    run env GIT_INDEX_FILE="$BATS_TEST_TMPDIR/scratch-index" \
        git -C "$REPO" commit -m "T-001: scratch"
    [ "$status" -ne 0 ]
    [[ "$output" == *".tasks/active/T-001-x.md"* ]]
    # and the real index, untouched, still commits fine
    echo "status: started-work" > "$REPO/.tasks/active/T-001-x.md"
    git -C "$REPO" add .tasks/active/T-001-x.md
    _commit real
    [ "$status" -eq 0 ]
}

@test "git mv of a stale entry (active -> completed) is refused via the rename source" {
    _stage_old .tasks/active/T-001-x.md
    git -C "$REPO" mv .tasks/active/T-001-x.md .tasks/completed/T-001-x.md
    _commit move
    [ "$status" -ne 0 ]
    [[ "$output" == *".tasks/completed/T-001-x.md"* ]]
    [[ "$output" == *"renamed from .tasks/active/T-001-x.md"* ]]
}

@test "a clean git mv of HEAD's content is allowed" {
    git -C "$REPO" mv .tasks/active/T-001-x.md .tasks/completed/T-001-x.md
    _commit move
    [ "$status" -eq 0 ]
}

@test "git commit --only of a fresh task edit is allowed (decision-commit shape)" {
    echo "status: decided" > "$REPO/.tasks/active/T-001-x.md"
    _commit_only=$(git -C "$REPO" commit -q --only .tasks/active/T-001-x.md -m "T-001: only" 2>&1; echo "rc=$?")
    [[ "$_commit_only" == *"rc=0"* ]]
}

@test "a large commit (>16 governed paths, prefix-walk branch) still catches the one stale entry" {
    for i in $(seq 10 30); do echo "status: captured" > "$REPO/.tasks/active/T-0$i-n.md"; done
    git -C "$REPO" add .tasks/active
    _stage_old .tasks/active/T-001-x.md
    echo "summary: v3" > "$REPO/.context/episodic/T-001.yaml"
    git -C "$REPO" add .context/episodic/T-001.yaml
    _commit big
    [ "$status" -ne 0 ]
    [[ "$output" == *".tasks/active/T-001-x.md: staged blob"* ]]
    [[ "$output" != *"T-001.yaml"* ]]
}

@test "override FW_ALLOW_STALE_INDEX=1 allows the commit and logs Tier-2" {
    _stage_old .tasks/active/T-001-x.md
    run env FW_ALLOW_STALE_INDEX=1 git -C "$REPO" commit -m "T-001: deliberate revert"
    [ "$status" -eq 0 ]
    [[ "$output" == *"bypassed via FW_ALLOW_STALE_INDEX=1"* ]]
    grep -q "flag: 'FW_ALLOW_STALE_INDEX=1'" "$REPO/.context/working/.gate-bypass-log.yaml"
    grep -q "paths: '.tasks/active/T-001-x.md'" "$REPO/.context/working/.gate-bypass-log.yaml"
}

# T-4584: a close stages `git mv active/X completed/X` (HEAD's pre-close blob) minutes
# before it re-stages the closed content; a commit in between landed 9 unclosed tasks in
# completed/ with `horizon: now`. A pure rename was waved through as "the normal move".
_unclosed_task() {
    printf -- '---\nid: T-003\nstatus: started-work\nhorizon: now\n---\n# T-003\n' \
        > "$REPO/.tasks/active/T-003-z.md"
    _commit_all "T-003: started"
}

@test "T-4584: git mv of an unclosed task (horizon set) into completed/ is refused" {
    _unclosed_task
    git -C "$REPO" mv .tasks/active/T-003-z.md .tasks/completed/T-003-z.md
    _commit move
    [ "$status" -ne 0 ]
    [[ "$output" == *".tasks/completed/T-003-z.md"* ]]
    [[ "$output" == *"horizon: now"* ]]
}

@test "T-4584: the closed move (horizon: null re-staged) is allowed" {
    _unclosed_task
    git -C "$REPO" mv .tasks/active/T-003-z.md .tasks/completed/T-003-z.md
    sed -i 's/^status:.*/status: work-completed/; s/^horizon:.*/horizon: null/' \
        "$REPO/.tasks/completed/T-003-z.md"
    git -C "$REPO" add .tasks/completed/T-003-z.md
    _commit close
    [ "$status" -eq 0 ]
}

@test "T-4584: horizon in the body, not the frontmatter, does not trip the check" {
    printf -- '---\nid: T-004\nhorizon: null\n---\nhorizon: now\n' > "$REPO/.tasks/completed/T-004-w.md"
    git -C "$REPO" add .tasks/completed/T-004-w.md
    _commit body
    [ "$status" -eq 0 ]
}
