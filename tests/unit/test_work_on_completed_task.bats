#!/usr/bin/env bats
# T-2036 — Pin `fw work-on T-XXX` behaviour against the P-002 "completed
# before commit" deadlock.
#
# Origin: T-2035 (session S-2026-0522-1941). If an agent runs
# `fw task update T-XXX --status work-completed` before committing the
# code, focus is nulled, the file moves to .tasks/completed/, and the
# check-active-task PreToolUse hook blocks every subsequent Bash mutation
# (git add/commit). The previous "recovery" `fw work-on T-XXX` silently
# false-succeeded — printed "Ready to work on T-XXX" while the task stayed
# in completed/ (work-completed is terminal in lib/enums.sh; update-task's
# transition failure was swallowed by `2>/dev/null || true`).
#
# Rules pinned here:
#   1. work-on on a completed task → exit 1 + actionable recovery message
#      (NOT silent false success).
#   2. work-on on a non-existent task → exit 1 + clear "not found" error.
#   3. work-on on an active task → exit 0, focus set (existing behaviour).
#   4. work-on does NOT swallow real update-task.sh failures any more.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-work-on"
    mkdir -p "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates" \
             "$TEST_PROJECT/.context/working"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
    # Stand up a minimal completed task and an active task
    cat > "$TEST_PROJECT/.tasks/completed/T-9001-already-done.md" <<'EOF'
---
id: T-9001
name: already done
status: work-completed
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: 2026-01-02T00:00:00Z
---
# done
EOF
    cat > "$TEST_PROJECT/.tasks/active/T-9002-in-progress.md" <<'EOF'
---
id: T-9002
name: in progress
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---
# wip
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "work-on on a completed task refuses with exit 1 and actionable message" {
    run "$FRAMEWORK_ROOT/bin/fw" work-on T-9001
    [ "$status" -eq 1 ]
    [[ "$output" == *"work-on refused: T-9001 is in .tasks/completed/"* ]]
    [[ "$output" == *"terminal — no transition back to started-work"* ]]
    [[ "$output" == *"FW_SWITCH_FOCUS=1 git commit"* ]]
    # Critical: must NOT print the false-success line that the old code emitted
    [[ "$output" != *"Ready to work on T-9001"* ]]
}

@test "work-on on a non-existent task refuses with exit 1" {
    run "$FRAMEWORK_ROOT/bin/fw" work-on T-9999
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found in .tasks/active/ or .tasks/completed/"* ]]
    [[ "$output" != *"Ready to work on T-9999"* ]]
}

@test "work-on on an active task succeeds (existing behaviour preserved)" {
    run "$FRAMEWORK_ROOT/bin/fw" work-on T-9002
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ready to work on T-9002"* ]]
}

@test "the silent-swallow string '2>/dev/null || true' is no longer wrapped around the started-work update" {
    # Regression marker: T-2036 removed the swallow at bin/fw:4841. If this
    # string ever creeps back the deadlock pattern returns.
    run grep -nE "task-create/update-task.sh.*started-work.*2>/dev/null.*\|\|.*true" "$FRAMEWORK_ROOT/bin/fw"
    [ "$status" -eq 1 ]  # grep miss = no match = good
}
