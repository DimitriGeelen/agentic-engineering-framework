#!/usr/bin/env bats
# T-4791 (OBS-452) — a task whose own commits changed a vendored path cannot reach
# work-completed while .agentic-framework/ is out of sync with it.
#
# Origin: T-3412's worker edited lib/inception.sh, agents/context/check-active-task.sh
# and agents/task-create/create-task.sh, never ran `fw vendor self`, and closed green:
# P-011 runs only the Verification lines the author wrote, and its author wrote none
# about vendor. Pre-push caught it later. The close gate now asks
# `fw vendor self --check --task <id>` itself (T-4419 scoping), framework repo only.
#
# Fixture: a temp framework repo built from `git archive HEAD` (never a working-tree
# copy, T-4702) with the update-task.sh under test copied in.

load ../test_helper

SRC_ROOT="$FRAMEWORK_ROOT"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    F="$TEST_TEMP_DIR/fw"
    mkdir -p "$F"
    git -C "$SRC_ROOT" archive HEAD bin lib agents .tasks/templates policy FRAMEWORK.md | tar -x -C "$F"
    cp "$SRC_ROOT/agents/task-create/update-task.sh" "$F/agents/task-create/update-task.sh"
    mkdir -p "$F/.agentic-framework/lib" "$F/.tasks/active" "$F/.tasks/completed" \
             "$F/.context/working" "$F/.context/episodic"
    echo "framework_root: $F" > "$F/.framework.yaml"
    # Every bin/fw call below must resolve to the fixture, never the real repo:
    # test_helper exports FRAMEWORK_ROOT=<source repo>, and `vendor self` writes there.
    export FRAMEWORK_ROOT="$F" PROJECT_ROOT="$F"
    unset FW_LIB_DIR
    guard_project_root
    unset CLAUDECODE FW_SKIP_VENDOR_SYNC FW_VENDOR_ONLY FW_VENDOR_ALL
    export FW_REVIEWER_DISABLED=1 FW_ISSUES_LIFECYCLE=0
    git -C "$F" init -q
    git -C "$F" config user.email t@t
    git -C "$F" config user.name t
    git -C "$F" config commit.gpgsign false
    ( cd "$F" && bash bin/fw vendor self >/dev/null 2>&1 ) || true
    git -C "$F" add -A >/dev/null
    git -C "$F" commit -qm "T-0001: base" --no-verify
    LOG="$F/.context/working/.gate-bypass-log.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1 task id
_task() {
    cat > "$F/.tasks/active/$1-fx.md" <<EOF
---
id: $1
name: "Vendor-sync fixture"
description: "T-4791 fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-10-28T00:00:00Z
last_update: 2026-10-28T00:00:00Z
date_finished: null
---

# $1: Vendor-sync fixture

## Acceptance Criteria

### Agent
- [x] The one criterion

## Verification
test -d /
EOF
}

# $1 task id, $2 repo-relative path to change and commit under that task
_commit_change() {
    echo "# $1 change" >> "$F/$2"
    git -C "$F" add "$2"
    git -C "$F" commit -qm "$1: change $2" --no-verify
}

_close() { ( cd "$F" && bash agents/task-create/update-task.sh "$1" --status work-completed "${@:2}" ); }
_closed() { [ -n "$(find "$F/.tasks/completed" -name "$1-*.md")" ]; }

@test "fixture: the vendored copy starts in sync" {
    run bash -c "cd '$F' && bash bin/fw vendor self --check"
    [ "$status" -eq 0 ]
}

@test "task changed a vendored path without syncing: close is refused" {
    _task T-9901
    _commit_change T-9901 lib/paths.sh
    run _close T-9901
    [ "$status" -ne 0 ]
    ! _closed T-9901 || false
    [[ "$output" == *"out of sync"* ]]
    [[ "$output" == *"lib/paths.sh"* ]]
}

@test "refusal names the fix command and both overrides" {
    _task T-9902
    _commit_change T-9902 lib/paths.sh
    run _close T-9902
    [ "$status" -ne 0 ]
    [[ "$output" == *"bin/fw vendor self --check --task T-9902"* ]]
    [[ "$output" == *"--skip-vendor-sync"* ]]
    [[ "$output" == *"FW_SKIP_VENDOR_SYNC=1"* ]]
}

@test "after fw vendor self the same task closes" {
    _task T-9903
    _commit_change T-9903 lib/paths.sh
    ( cd "$F" && bash bin/fw vendor self >/dev/null 2>&1 )
    run _close T-9903
    [ "$status" -eq 0 ]
    _closed T-9903
}

@test "task whose commits touch no vendored path closes untouched" {
    _task T-9904
    mkdir -p "$F/docs"
    _commit_change T-9904 docs/note.md
    run _close T-9904
    [ "$status" -eq 0 ]
    _closed T-9904
}

@test "another task's drift does not block this one" {
    _task T-9905
    _commit_change T-9906 lib/paths.sh
    run _close T-9905
    [ "$status" -eq 0 ]
    _closed T-9905
}

@test "consumer project (no self-vendor): close is not gated" {
    rm -rf "$F/.agentic-framework/lib"
    _task T-9907
    _commit_change T-9907 lib/paths.sh
    run _close T-9907
    [ "$status" -eq 0 ]
    _closed T-9907
}

@test "operator override with a reason closes and logs Tier-2" {
    _task T-9908
    _commit_change T-9908 lib/paths.sh
    run _close T-9908 --skip-vendor-sync "fixture keeps the copy stale"
    [ "$status" -eq 0 ]
    _closed T-9908
    grep -q "flag: '--skip-vendor-sync'" "$LOG"
    grep -q "reason: 'fixture keeps the copy stale'" "$LOG"
}

@test "override without a reason is refused" {
    _task T-9909
    _commit_change T-9909 lib/paths.sh
    run _close T-9909 --skip-vendor-sync
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs a reason"* ]]
}

@test "flag override is refused in an agent session without --i-am-human" {
    _task T-9910
    _commit_change T-9910 lib/paths.sh
    CLAUDECODE=1 run _close T-9910 --skip-vendor-sync "agent tries"
    [ "$status" -ne 0 ]
    ! _closed T-9910 || false
}

@test "env override is refused in an agent session, logged when not" {
    _task T-9911
    _commit_change T-9911 lib/paths.sh
    CLAUDECODE=1 FW_SKIP_VENDOR_SYNC=1 run _close T-9911
    [ "$status" -ne 0 ]
    [[ "$output" == *"FW_SKIP_VENDOR_SYNC=1 is refused"* ]]
    FW_SKIP_VENDOR_SYNC=1 run _close T-9911
    [ "$status" -eq 0 ]
    _closed T-9911
    grep -q "flag: 'FW_SKIP_VENDOR_SYNC'" "$LOG"
}
