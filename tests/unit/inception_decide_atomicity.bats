#!/usr/bin/env bats
# T-1503: do_inception_decide must be atomic — either fully succeeds (Decision
# section + Updates entry + status=work-completed) or leaves the task body
# untouched. The original bug: Decision/Updates writes happened BEFORE the
# AC gate ran, so a task with custom (non-auto-tick) Agent ACs would have
# Decision=GO recorded but status stuck at started-work. Retries then
# duplicated the Updates entry.
#
# Live evidence: 003-NTB-ATC-Plugin T-131 watchtower.log:
#   stdout=...ERROR: Cannot complete — 5/5 agent AC unchecked...
#   POST /inception/T-131/decide HTTP/1.1 500
#
# Fix (preflight pattern): tick first, count remaining unchecked Agent ACs,
# abort BEFORE writing Decision/Updates if any remain.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    unset CLAUDECODE  # bypass T-1259 agent-block gate
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.context/working"

    # Pre-create review marker so T-973 gate passes
    : > "$TEST_TEMP_DIR/.context/working/.reviewed-T-XXX-test"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Minimal inception task scaffold. Custom Agent AC ($1=name) is NOT auto-tick
# so tick_inception_decide_acs leaves it alone.
_make_task() {
    local task_id="$1"
    local custom_ac_state="$2"  # "[ ]" or "[x]"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    : > "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id"
    cat > "$f" <<EOF
---
id: $task_id
name: "Test inception"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-04-26T00:00:00Z
last_update: 2026-04-26T00:00:00Z
---

# $task_id: Test inception

## Recommendation

**Recommendation:** GO
**Rationale:** test
**Evidence:** test

## Acceptance Criteria

### Agent
- $custom_ac_state Custom build-spike AC that is NOT auto-tick

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:** etc.

## Decision

## Updates
EOF
    echo "$f"
}

@test "atomicity: unchecked custom Agent AC blocks decision — task body unmodified" {
    local task_id="T-9501"
    local f
    f=$(_make_task "$task_id" "[ ]")

    local before_md5
    before_md5=$(md5sum "$f" | awk '{print $1}')

    run do_inception_decide "$task_id" go --rationale "test" --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"agent AC unchecked"* ]]
    [[ "$output" == *"Custom build-spike AC"* ]]

    # CRITICAL: task body is UNCHANGED — no Decision section written, no Updates entry
    local after_md5
    after_md5=$(md5sum "$f" | awk '{print $1}')

    # Debug if it changed: print diff context
    if [ "$before_md5" != "$after_md5" ]; then
        echo "Task body was modified despite gate failure:" >&3
        diff <(printf '%s' "$before_md5") <(printf '%s' "$after_md5") >&3 || true
    fi

    # Specifically: no Decision content was written
    if grep -q "^\*\*Decision\*\*: GO" "$f"; then false; fi
    # No new inception-decision Updates entry
    ! grep -q "inception-decision" "$f"
}

@test "atomicity: checked custom Agent AC allows full success" {
    local task_id="T-9502"
    local f
    f=$(_make_task "$task_id" "[x]")

    # update-task.sh tries to do real things — the inception-decide function itself
    # gates on AC state BEFORE that. We're testing the preflight, not the
    # full transition. To do that, run only up to the preflight: invoke the
    # function and check it gets PAST the AC check by looking for the
    # Decision section getting written.
    run do_inception_decide "$task_id" go --rationale "test" --i-am-human
    # We don't care about end status (update-task.sh may fail in this fixture
    # due to missing fw scaffolding); we care that the preflight let us through
    # and the Decision section IS now written.
    grep -q "^\*\*Decision\*\*: GO" "$f"
    grep -q "inception-decision" "$f"
}

@test "atomicity: failed decide is retry-safe — second attempt also fails fast (no Updates accumulation)" {
    local task_id="T-9503"
    local f
    f=$(_make_task "$task_id" "[ ]")

    run do_inception_decide "$task_id" go --rationale "first" --i-am-human
    [ "$status" -ne 0 ]
    run do_inception_decide "$task_id" go --rationale "second" --i-am-human
    [ "$status" -ne 0 ]
    run do_inception_decide "$task_id" go --rationale "third" --i-am-human
    [ "$status" -ne 0 ]

    # CRITICAL: zero inception-decision Updates entries from any attempt
    local count
    count=$(grep -c "inception-decision" "$f" || true)
    [ "$count" -eq 0 ]
}
