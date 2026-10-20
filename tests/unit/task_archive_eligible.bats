#!/usr/bin/env bats
# T-1903 / L-403: `fw task archive-eligible` sweep — detect tasks stuck in
# .tasks/active/ with status: work-completed + all ACs ticked (the post-
# re-class trap) and move them to .tasks/completed/.
#
# Origin: T-1890 found this state after T-1894 re-classed its only Human AC
# to [REVIEWER] under ### Agent. The first work-completed transition had set
# PARTIAL_COMPLETE=true (Human AC unchecked at the time) → owner=human, file
# stayed in active/. The recheck logic in update-task.sh (line ~941) only
# fires when --status work-completed is re-invoked — which nothing does
# automatically after a re-class. Sweep verb runs that re-invocation in bulk.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # Synthetic project root — avoid touching real .tasks/.
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed" \
             "$TEST_ROOT/.context/working" "$TEST_ROOT/.context/episodic"
    # Minimal focus.yaml so update-task.sh doesn't refuse on missing context
    cat > "$TEST_ROOT/.context/working/focus.yaml" <<'EOF'
current_task: null
priorities: []
EOF
    cd "$TEST_ROOT"
    # Pin PROJECT_ROOT to the test sandbox. Without this, an inherited
    # PROJECT_ROOT from the parent (e.g. when update-task.sh runs this
    # bats file under the verification gate) makes bin/fw walk the
    # real project's .tasks/ instead of $TEST_ROOT.
    export PROJECT_ROOT="$TEST_ROOT"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# Helper — write a task file with the given fields.
_write_task() {
    local task_id="$1" status="$2" body="$3" dir="${4:-active}"
    local fn="$TEST_ROOT/.tasks/$dir/${task_id}-test.md"
    cat > "$fn" <<EOF
---
id: $task_id
name: "test task"
description: >
  test
status: $status
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-18T00:00:00Z
last_update: 2026-05-18T00:00:00Z
date_finished: 2026-05-18T00:00:00Z
---

# $task_id: test

## Acceptance Criteria

$body

## Verification

true
EOF
    echo "$fn"
}

@test "T-1903: --dry-run on empty active/ reports no-op" {
    rm -f "$TEST_ROOT"/.tasks/active/T-*.md
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"No stuck"* ]] || [[ "$output" == *"no-op"* ]]
}

@test "T-1903: detector finds a stuck partial-complete (all ACs ticked, in active/)" {
    _write_task "T-9001" "work-completed" \
"### Agent
- [x] dummy agent AC
"
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" == *"dry-run"* ]]
    # File NOT moved by dry-run
    [ -f "$TEST_ROOT/.tasks/active/T-9001-test.md" ]
}

@test "T-1903: detector ignores task with unchecked AC" {
    _write_task "T-9002" "work-completed" \
"### Agent
- [x] checked
- [ ] still pending
"
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9002"* ]]
}

@test "T-4180: detector finds started-work task with every AC ticked (CTL-029 class)" {
    _write_task "T-9003" "started-work" \
"### Agent
- [x] dummy
"
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9003"* ]]
    [ -f "$TEST_ROOT/.tasks/active/T-9003-test.md" ]
}

@test "T-4180: detector ignores started-work task with an unticked AC" {
    _write_task "T-9005" "started-work" \
"### Agent
- [x] done
- [ ] not yet
"
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9005"* ]]
}

@test "T-4180: detector ignores started-work task with only template placeholder ACs" {
    _write_task "T-9006" "started-work" \
"### Agent
- [x] [First criterion]
- [x] [Second criterion]
"
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9006"* ]]
}

@test "T-4180: detector still ignores captured and issues tasks" {
    _write_task "T-9007" "captured" \
"### Agent
- [x] dummy
"
    _write_task "T-9008" "issues" \
"### Agent
- [x] dummy
"
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-9007"* ]]
    [[ "$output" != *"T-9008"* ]]
}

@test "T-4180: sweep closes an eligible started-work task into completed/" {
    _write_task "T-9009" "started-work" \
"### Agent
- [x] dummy
"
    # Owner agent so the close is a plain completion, not partial-complete.
    # A real verification line: the close gates still run, and refuse `true`.
    sed -i -e 's/^owner: human/owner: agent/' \
           -e 's|^true$|grep -q "^id: T-9009" .tasks/active/T-9009-test.md|' \
        "$TEST_ROOT/.tasks/active/T-9009-test.md"
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --verbose
    [ ! -f "$TEST_ROOT/.tasks/active/T-9009-test.md" ]
    [ -f "$TEST_ROOT/.tasks/completed/T-9009-test.md" ]
    [[ "$output" == *"archived"* ]]
}

@test "T-1903: HTML-comment-stripped detector ignores template placeholder unchecked ACs" {
    _write_task "T-9004" "work-completed" \
"### Agent
- [x] real AC
<!--
- [ ] placeholder in HTML comment, should NOT count
-->
"
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --dry-run
    [ "$status" -eq 0 ]
    # T-9004 should be flagged: HTML-comment unchecked is stripped
    [[ "$output" == *"T-9004"* ]]
}

@test "T-1903: --help exits 0 and mentions L-403" {
    run "$FRAMEWORK_ROOT/bin/fw" task archive-eligible --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"L-403"* ]] || [[ "$output" == *"archive"* ]]
}
