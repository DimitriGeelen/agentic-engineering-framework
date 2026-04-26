#!/usr/bin/env bats
# T-1509: do_inception_decide must exit 0 on a clean go/no-go path.
#
# Original bug: lib/inception.sh:318 resolved task_file to the active/ path,
# then update-task.sh moved the file to completed/ at line 494, leaving
# task_file stale. Line 508 called emit_review with that stale path; review.sh
# bailed with `return 1` when `[ ! -f "$task_file" ]`, set -e propagated, and
# bin/fw exited non-zero. Watchtower's record_decision saw ok=False and
# rendered a spurious side-effect warning even though the primary decision
# had already landed in the task body.
#
# Fix: lib/review.sh treats task_file arg as a HINT — falls back to discovery
# when the path is empty or invalid. lib/inception.sh:508 also drops the
# stale arg as defense in depth.
#
# Live evidence: T-1505 GO via Watchtower at 12:58:45Z — task moved to
# completed/, episodic generated, but warning "Decision recorded; side-effect
# warning: === Task Update ===..." fired, surfacing the leaked banner.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    # Bypass T-1259 agent-block; bypass _watchtower_url discovery (no live Flask in test)
    unset CLAUDECODE
    export WATCHTOWER_URL="http://test.invalid:3000"

    mkdir -p "$TEST_TEMP_DIR/.tasks/active" \
             "$TEST_TEMP_DIR/.tasks/completed" \
             "$TEST_TEMP_DIR/.context/working" \
             "$TEST_TEMP_DIR/.context/episodic" \
             "$TEST_TEMP_DIR/.context/project"
    : > "$TEST_TEMP_DIR/.context/working/.reviewed-T-9501"
    echo "id: TEST" > "$TEST_TEMP_DIR/.framework.yaml"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh" 2>/dev/null || true
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_inception() {
    local task_id="$1"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    cat > "$f" <<EOF
---
id: $task_id
name: "Post-move emit_review test"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-04-26T00:00:00Z
last_update: 2026-04-26T00:00:00Z
---

# $task_id: Post-move emit_review test

## Recommendation

**Recommendation:** GO
**Rationale:** test
**Evidence:** test

## Acceptance Criteria

### Agent
- [x] All ticked

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Approve

## Decision

## Updates
EOF
    echo "$f"
}

@test "post-move: do_inception_decide exits 0 when emit_review sees stale task_file" {
    local task_id="T-9501"
    local f
    f=$(_make_inception "$task_id")
    : > "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id"

    # Run under the same set -Eeuo pipefail that bin/fw uses, so any non-zero
    # return inside do_inception_decide propagates exactly as in production.
    # `run` already isolates in a subshell — apply set + call directly.
    _decide_under_strict() {
        set -Eeuo pipefail
        do_inception_decide "$1" go --rationale "test" --i-am-human
    }
    run _decide_under_strict "$task_id"
    [ "$status" -eq 0 ]
    # Decision must have landed in the now-completed task body
    [ -f "$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md" ]
    grep -q "^\*\*Decision\*\*: GO" "$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md"
    # emit_review must have rediscovered the moved file and re-created the marker
    [ -f "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id" ]
}

@test "emit_review: stale task_file arg falls back to discovery (does not return 1)" {
    local task_id="T-9502"
    local f
    f=$(_make_inception "$task_id")
    # Move the file to simulate post-update-task.sh state
    mv "$f" "$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md"

    source "$FRAMEWORK_ROOT/lib/review.sh"
    # Pass the stale active/ path. Pre-fix: emit_review returned 1.
    # Post-fix: discovery falls back to completed/ and emit_review succeeds.
    run emit_review "$task_id" "$f"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$task_id"* ]]
}

@test "emit_review: invalid arg AND no discoverable file still returns 1 (preserved behavior)" {
    source "$FRAMEWORK_ROOT/lib/review.sh"
    run emit_review "T-9999-nonexistent" "/tmp/does/not/exist.md"
    [ "$status" -eq 1 ]
}
