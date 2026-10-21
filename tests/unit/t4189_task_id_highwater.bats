#!/usr/bin/env bats
# Regression: a deleted task's id is never reissued (T-4189, 832 OBS-426).
#
# generate_id took "main-cluster max + 1" over the task files that exist now,
# so deleting the highest-numbered file lowered the ceiling and the next mint
# reused its id. It now persists a high-water mark (.tasks/.id-highwater) at
# allocation time and takes the max with it — the T-2966 pattern for OBS ids.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CREATE_TASK="$FRAMEWORK_ROOT/agents/task-create/create-task.sh"

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_DIR="$BATS_TMPDIR/fw_id_highwater_test_$$"
    mkdir -p "$TEST_DIR/active" "$TEST_DIR/completed" "$TEST_DIR/templates"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TEST_DIR/templates/default.md" 2>/dev/null || true
    export TASKS_DIR="$TEST_DIR"
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    # Same hermeticity fences as t100202_id_quarantine.bats.
    export GIT_CEILING_DIRECTORIES="$(dirname "$BATS_TMPDIR")"
    unset CLAUDECODE FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED
    unset _FW_PATHS_DERIVED_BY
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

_seed() { : > "$TEST_DIR/active/$1.md"; }

_mint() {
    run timeout 15 "$CREATE_TASK" --name "$1" --description "d" --type build --owner agent < /dev/null
    [ "$status" -eq 0 ]
}

@test "T-4189: deleting the highest-numbered task does not let its id be reissued" {
    _seed "T-0010-a"
    _seed "T-0011-b"
    _mint "First probe"
    ls "$TEST_DIR/active/" | grep -q '^T-012-'
    rm -f "$TEST_DIR"/active/T-012-*.md
    _mint "Second probe"
    ls "$TEST_DIR/active/" | grep -q '^T-013-'
    ! ls "$TEST_DIR/active/" | grep -q '^T-012-' || false
}

@test "T-4189: allocation writes the high-water mark" {
    _seed "T-0010-a"
    _mint "Mark probe"
    [ "$(cat "$TEST_DIR/.id-highwater")" = "11" ]
}

@test "T-4189: an existing mark above the file max wins" {
    _seed "T-0010-a"
    printf '50\n' > "$TEST_DIR/.id-highwater"
    _mint "Mark wins probe"
    ls "$TEST_DIR/active/" | grep -q '^T-051-'
}

@test "T-4189: a mark beyond the quarantine gap is ignored (T-100202 still holds)" {
    _seed "T-2524-seed"
    printf '99971\n' > "$TEST_DIR/.id-highwater"
    _mint "Quarantined mark probe"
    ls "$TEST_DIR/active/" | grep -q '^T-2525-'
    ! ls "$TEST_DIR/active/" | grep -q '^T-99972-' || false
}

@test "T-4189: deleting every task file still does not restart at T-001" {
    printf '5\n' > "$TEST_DIR/.id-highwater"
    _mint "Empty corpus probe"
    ls "$TEST_DIR/active/" | grep -q '^T-006-'
}

@test "T-4189: a garbage mark is ignored rather than breaking allocation" {
    _seed "T-0010-a"
    printf 'not-a-number\n' > "$TEST_DIR/.id-highwater"
    _mint "Garbage mark probe"
    ls "$TEST_DIR/active/" | grep -q '^T-011-'
}

@test "T-4189: the mark of another worktree's view is honoured" {
    local repo="$TEST_DIR/repo" wt="$TEST_DIR/wt"
    mkdir -p "$repo/.tasks/active" "$repo/.tasks/completed" "$repo/.tasks/templates"
    cp "$TEST_DIR/templates/default.md" "$repo/.tasks/templates/default.md" 2>/dev/null || true
    : > "$repo/.tasks/active/T-0010-a.md"
    git -C "$repo" init -q
    git -C "$repo" -c user.email=t@t -c user.name=t add -A
    git -C "$repo" -c user.email=t@t -c user.name=t commit -qm seed
    git -C "$repo" worktree add -q "$wt" -b side
    # The worktree minted (and then dropped) up to 40; main must not reissue it.
    printf '40\n' > "$wt/.tasks/.id-highwater"
    export TASKS_DIR="$repo/.tasks"
    _mint "Cross-view probe"
    ls "$repo/.tasks/active/" | grep -q '^T-041-'
}
