#!/usr/bin/env bats
# T-4727: `fw inception decide` warns (never blocks) when the recorded verb
# differs from the task's Recommendation verdict, and notes the divergence in
# `## Decision` as `**Diverges from Recommendation**: <REC>`.
#
# The verdict comes from web.shared.extract_recommendation — the parser the
# Watchtower Recommendation card uses — so an unparseable verdict is silent.
# Watchtower's decide (web/decide_runner.py) shells the same CLI, so these
# tests cover its note too.
#
# Origin: TermLink's T-2958 — 23 of 140 completed inceptions had a Decision
# that differed from the Recommendation, with nothing in the record saying so.

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

# $1 task id, $2 the value after `**Recommendation:**`
_make_inception() {
    local task_id="$1" verdict="$2"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    : > "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id"
    cat > "$f" <<EOF
---
id: $task_id
name: "Diverges warning test"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-10-24T00:00:00Z
last_update: 2026-10-24T00:00:00Z
---

# $task_id: Diverges warning test

## Recommendation

**Recommendation:** $verdict

**Rationale:** test rationale

**Evidence:**
- evidence point 1

## Acceptance Criteria

### Agent
- [x] All ticked

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Approve

## Decision

## Updates
EOF
}

# Decide under strict mode; stderr goes to $TEST_TEMP_DIR/err.
_decide() {
    set -Eeuo pipefail
    do_inception_decide "$1" "$2" --rationale "test" --i-am-human 2>"$TEST_TEMP_DIR/err"
}

# The task file after decide: completed/ for go/no-go, active/ for defer.
_decided_file() {
    ls "$TEST_TEMP_DIR"/.tasks/completed/"$1"-test.md "$TEST_TEMP_DIR"/.tasks/active/"$1"-test.md 2>/dev/null | head -1
}

@test "mismatch: NO-GO recommendation decided go warns on stderr and notes it in ## Decision" {
    _make_inception T-9701 "NO-GO"
    run _decide T-9701 go
    [ "$status" -eq 0 ]
    grep -q "WARNING: recording GO but the Recommendation is NO-GO (T-4727)" "$TEST_TEMP_DIR/err"
    local f
    f=$(_decided_file T-9701)
    [ -n "$f" ]
    # The decision is still recorded — a warning, never a block.
    grep -q '^\*\*Decision\*\*: GO$' "$f"
    grep -q '^\*\*Diverges from Recommendation\*\*: NO-GO$' "$f"
}

@test "match: GO recommendation decided go — no warning, no note" {
    _make_inception T-9702 "GO"
    run _decide T-9702 go
    [ "$status" -eq 0 ]
    ! grep -q "T-4727" "$TEST_TEMP_DIR/err" || false
    local f
    f=$(_decided_file T-9702)
    grep -q '^\*\*Decision\*\*: GO$' "$f"
    ! grep -q 'Diverges from Recommendation' "$f" || false
}

@test "match: DEFER recommendation decided defer — no warning, no note" {
    _make_inception T-9703 "DEFER"
    run _decide T-9703 defer
    [ "$status" -eq 0 ]
    ! grep -q "T-4727" "$TEST_TEMP_DIR/err" || false
    local f
    f=$(_decided_file T-9703)
    grep -q '^\*\*Decision\*\*: DEFER$' "$f"
    ! grep -q 'Diverges from Recommendation' "$f" || false
}

@test "unparseable verdict: no warning, no note" {
    _make_inception T-9704 "Proceed with caution"
    run _decide T-9704 go
    [ "$status" -eq 0 ]
    ! grep -q "T-4727" "$TEST_TEMP_DIR/err" || false
    local f
    f=$(_decided_file T-9704)
    grep -q '^\*\*Decision\*\*: GO$' "$f"
    ! grep -q 'Diverges from Recommendation' "$f" || false
}

@test "verdict with trailing prose is parsed like Watchtower: 'GO — narrow slice' decided defer warns" {
    _make_inception T-9705 "GO — build the narrow slice"
    run _decide T-9705 defer
    [ "$status" -eq 0 ]
    grep -q "WARNING: recording DEFER but the Recommendation is GO (T-4727)" "$TEST_TEMP_DIR/err"
    grep -q '^\*\*Diverges from Recommendation\*\*: GO$' "$(_decided_file T-9705)"
}
