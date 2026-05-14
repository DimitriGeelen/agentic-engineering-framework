#!/usr/bin/env bats
# T-1832: lib/inception.sh Python decide-handler auto-creates `## Decision`
# section when missing, instead of silently no-op'ing.
#
# Origin: S-2026-0514 errors 4-5 (T-1831 Layer 2 RCA). When a task file lacks
# the singular `## Decision` heading (default.md only has `## Decisions`
# plural), the Python in lib/inception.sh:531-582 iterated lines looking for
# `line.strip() == '## Decision'`, never found it, and left decision_written
# False — no Decision block written. The function returned 0. Caller then
# ticked the Human AC and invoked update-task.sh --status work-completed,
# which failed at check_inception_decision (`**Decision**:` grep) with the
# misleading "no decision recorded" error.
#
# Fix: when the loop finishes with decision_written still False, synthesize
# the `## Decision` block, insert it before `## Updates` (or
# `## Recommendation`, or at EOF), and emit a stderr warning so the
# auto-creation is visible.

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
    unset CLAUDECODE
    export WATCHTOWER_URL="http://test.invalid:3000"

    mkdir -p "$TEST_TEMP_DIR/.tasks/active" \
             "$TEST_TEMP_DIR/.tasks/completed" \
             "$TEST_TEMP_DIR/.context/working" \
             "$TEST_TEMP_DIR/.context/episodic" \
             "$TEST_TEMP_DIR/.context/project"
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

# Task WITH the canonical `## Decision` heading — normal path.
_make_with_heading() {
    local task_id="$1"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    cat > "$f" <<EOF
---
id: $task_id
name: "T-1832 with-heading test"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-05-14T00:00:00Z
last_update: 2026-05-14T00:00:00Z
---

# $task_id: With heading

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

# Task WITHOUT `## Decision` heading — exercises auto-create.
_make_without_heading() {
    local task_id="$1"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    cat > "$f" <<EOF
---
id: $task_id
name: "T-1832 without-heading test"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-05-14T00:00:00Z
last_update: 2026-05-14T00:00:00Z
---

# $task_id: Without heading

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

## Decisions

(plural-only template variant — no singular Decision section)

## Updates
EOF
    echo "$f"
}

@test "auto-create: task lacking '## Decision' gets section inserted with warning" {
    local task_id="T-9601"
    local f
    f=$(_make_without_heading "$task_id")

    : > "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id"
    run do_inception_decide "$task_id" go --rationale "auto-create test" --i-am-human

    # do_inception_decide may exit non-zero from downstream work-completed
    # gates in this minimal test env — but T-1832 fix is specifically about
    # the Python decide-handler section. Assert the actual fix outcome on
    # the file regardless of overall exit code.

    # The task may have moved to completed/ even on partial flow — check both.
    local final="$f"
    [ -f "$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md" ] && final="$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md"

    # Decision section must now exist (auto-created).
    grep -q "^## Decision$" "$final"
    grep -q "^\*\*Decision\*\*: GO" "$final"
    grep -q "auto-create test" "$final"

    # Auto-create warning must have fired to stderr.
    [[ "$output" == *"T-1832"* ]]
    [[ "$output" == *"auto-created"* ]]

    # The Decision block must be inserted BEFORE the Updates section
    # (preserves Updates-at-end invariant).
    local decision_line updates_line
    decision_line=$(grep -n "^## Decision$" "$final" | head -1 | cut -d: -f1)
    updates_line=$(grep -n "^## Updates$" "$final" | head -1 | cut -d: -f1)
    [ -n "$decision_line" ]
    [ -n "$updates_line" ]
    [ "$decision_line" -lt "$updates_line" ]
}

@test "auto-create: task WITH '## Decision' takes normal path, no warning" {
    local task_id="T-9602"
    local f
    f=$(_make_with_heading "$task_id")

    : > "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id"
    run do_inception_decide "$task_id" go --rationale "normal path test" --i-am-human

    local final="$f"
    [ -f "$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md" ] && final="$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md"

    grep -q "^## Decision$" "$final"
    grep -q "^\*\*Decision\*\*: GO" "$final"
    grep -q "normal path test" "$final"

    # Auto-create warning must NOT fire when the heading was already present.
    [[ "$output" != *"auto-created"* ]]
}

@test "auto-create: NO-GO path also writes Decision when heading missing" {
    local task_id="T-9603"
    local f
    f=$(_make_without_heading "$task_id")

    : > "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id"
    run do_inception_decide "$task_id" no-go --rationale "rejected" --i-am-human

    local final="$f"
    [ -f "$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md" ] && final="$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md"

    grep -q "^\*\*Decision\*\*: NO-GO" "$final"
    [[ "$output" == *"auto-created"* ]]
}
