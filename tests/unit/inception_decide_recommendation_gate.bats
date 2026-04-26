#!/usr/bin/env bats
# T-1497: do_inception_decide must refuse when ## Recommendation has no
# substantive **Recommendation:** line outside HTML comments.
#
# Original regression: pickup-created inceptions (lib/pickup.sh) get a
# template skeleton with `## Recommendation` containing only an HTML-comment
# placeholder. The previous inline check at lib/inception.sh:358 used
# `grep -v '^<!--'` which only filters the OPENING line of a multi-line
# comment. The COMMENTED `**Recommendation:** GO / NO-GO / DEFER` template
# line then leaked past the filter and the gate accepted the empty section.
#
# Live evidence: T-1501 + T-1502 (this session) reached the human review
# queue with empty Recommendation bodies. User flagged the regression
# directly: "what am I deciding for / on?".
#
# Fix: lib/task-audit.sh:audit_inception_recommendation uses awk to track
# multi-line HTML-comment state, then greps for a non-commented
# **Recommendation:** line. lib/inception.sh:do_inception_decide replaces
# the broken inline check with a call to the helper.

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
    source "$FRAMEWORK_ROOT/lib/task-audit.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build an inception task. $2 is the literal Recommendation section body
# (between the heading and the next `## `).
_make_inception_with_rec() {
    local task_id="$1"
    local rec_body="$2"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    : > "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id"
    cat > "$f" <<EOF
---
id: $task_id
name: "Recommendation gate test"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-04-26T00:00:00Z
last_update: 2026-04-26T00:00:00Z
---

# $task_id: Recommendation gate test

## Recommendation

$rec_body

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

@test "audit_inception_recommendation: HTML-comment-only block returns 1 (the regression)" {
    local f
    f=$(_make_inception_with_rec "T-9601" '<!-- REQUIRED before fw inception decide. Write your recommendation here.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence)
     **Evidence:**
     - Finding 1
-->')

    run audit_inception_recommendation "$f"
    [ "$status" -eq 1 ]
}

@test "audit_inception_recommendation: substantive **Recommendation:** line returns 0" {
    local f
    f=$(_make_inception_with_rec "T-9602" '**Recommendation:** GO

**Rationale:** Tests pass, evidence is solid.

**Evidence:**
- Test 1
- Test 2')

    run audit_inception_recommendation "$f"
    [ "$status" -eq 0 ]
}

@test "audit_inception_recommendation: completely empty section returns 1" {
    local f
    f=$(_make_inception_with_rec "T-9603" '')

    run audit_inception_recommendation "$f"
    [ "$status" -eq 1 ]
}

@test "audit_inception_recommendation: indented **Recommendation:** still passes" {
    local f
    f=$(_make_inception_with_rec "T-9604" '  **Recommendation:** NO-GO

  **Rationale:** Reasoned argument.')

    run audit_inception_recommendation "$f"
    [ "$status" -eq 0 ]
}

@test "do_inception_decide: refuses when Recommendation block is HTML-comment only" {
    local task_id="T-9605"
    local f
    f=$(_make_inception_with_rec "$task_id" '<!--
**Recommendation:** GO / NO-GO / DEFER
**Rationale:** Why
-->')

    _decide_under_strict() {
        set -Eeuo pipefail
        do_inception_decide "$1" go --rationale "test" --i-am-human
    }
    run _decide_under_strict "$task_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Recommendation section required"* ]]
    # Task body must not have a Decision recorded
    ! grep -q "^\*\*Decision\*\*: GO" "$f"
}

@test "do_inception_decide: succeeds with substantive Recommendation" {
    local task_id="T-9606"
    local f
    f=$(_make_inception_with_rec "$task_id" '**Recommendation:** GO

**Rationale:** test rationale

**Evidence:**
- evidence point 1')

    _decide_under_strict() {
        set -Eeuo pipefail
        do_inception_decide "$1" go --rationale "test" --i-am-human
    }
    run _decide_under_strict "$task_id"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md" ]
    grep -q "^\*\*Decision\*\*: GO" "$TEST_TEMP_DIR/.tasks/completed/$task_id-test.md"
}
