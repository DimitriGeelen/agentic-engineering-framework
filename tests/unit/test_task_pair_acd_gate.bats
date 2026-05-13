#!/usr/bin/env bats
# T-1762: task-pair §ACD gate (P-012) — gate behaviour (T-1713 Spike 3)
#
# Tests for check_task_pair_acd in agents/task-create/update-task.sh
#
# Pins gate behaviour:
#   - Build task with all promised deliverables shipped → passes
#   - Build task with missing deliverables → exit 1 with actionable message
#   - --scope-reduction-acknowledged "..." → bypasses with logged Tier-2 entry
#   - Build task whose inception has no Decomposition heading → no-op (single-deliverable)
#   - Non-build tasks (inception/spec/design) → no-op
#   - Build task with no related_tasks → no-op
#   - Existing P-010/P-011 still run before P-012 (regression)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.tasks/templates"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" \
       "$TEST_TEMP_DIR/.tasks/templates/default.md" 2>/dev/null || true
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# ---- Helpers ------------------------------------------------------------

write_inception_with_decomposition() {
    local id="$1"
    local file="$TEST_TEMP_DIR/.tasks/completed/${id}-test-inception.md"
    cat > "$file" <<EOF
---
id: $id
name: "Test inception with B1+B2 decomposition"
status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-06T00:00:00Z
last_update: 2026-05-06T00:00:00Z
date_finished: 2026-05-06T00:00:00Z
---

## Recommendation

**Recommendation:** GO

**Rationale:** because.

**Decomposition (follow-up build tasks after GO):**
- B1: First widget implementation
- B2: Second sprocket implementation

EOF
    echo "$file"
}

write_inception_without_decomposition() {
    local id="$1"
    local file="$TEST_TEMP_DIR/.tasks/completed/${id}-single-deliverable.md"
    cat > "$file" <<EOF
---
id: $id
name: "Single-deliverable inception"
status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-06T00:00:00Z
last_update: 2026-05-06T00:00:00Z
date_finished: 2026-05-06T00:00:00Z
---

## Recommendation

**Recommendation:** GO

**Rationale:** single deliverable, no decomposition.

EOF
    echo "$file"
}

write_build_task() {
    local id="$1"
    local title="$2"
    local related="$3"  # JSON-style "[T-XXX, T-YYY]"
    local file="$TEST_TEMP_DIR/.tasks/active/${id}-build-task.md"
    cat > "$file" <<EOF
---
id: $id
name: "$title"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: $related
created: 2026-05-06T00:00:00Z
last_update: 2026-05-06T00:00:00Z
date_finished: null
---

## Acceptance Criteria

### Agent
- [x] Done

## Verification

EOF
    echo "$file"
}

run_check() {
    local task_file="$1"
    local scope_ack="${2:-}"
    local pr="${PROJECT_ROOT:-$TEST_TEMP_DIR}"
    cd "$TEST_TEMP_DIR" || return 1
    # NOTE: `set -euo pipefail` mirrors update-task.sh's actual mode. Without
    # this line the test ran in vanilla bash and silently masked a real bug
    # where a `var=$(cmd)` assignment after a separate `local var` triggered
    # set-e exit on cmd non-zero, killing the function before any stderr
    # diagnostic fired. Production was silent; tests were green. (Origin:
    # T-1762 dogfooding — own gate refused itself silently.)
    bash -c "
        set -euo pipefail
        export PROJECT_ROOT='$pr'
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        export TASK_FILE='$task_file'
        export NEW_STATUS='work-completed'
        export SCOPE_REDUCTION_ACK='$scope_ack'
        # Stub log_gate_bypass (defined elsewhere in update-task.sh)
        log_gate_bypass() { echo \"BYPASS: \$1 — \$2\" >> $TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml; }
        # Color stubs
        GREEN=''; RED=''; YELLOW=''; NC=''; CYAN=''
        # Source the lib + the function we want to test
        source '$FRAMEWORK_ROOT/lib/task_pair_acd.sh'
        # Extract just check_task_pair_acd function source
        eval \"\$(awk '/^check_task_pair_acd\\(\\) \\{/,/^\\}/' '$FRAMEWORK_ROOT/agents/task-create/update-task.sh')\"
        check_task_pair_acd
    "
}

# ---- Tests --------------------------------------------------------------

@test "Build with all deliverables shipped — passes" {
    write_inception_with_decomposition "T-9100" >/dev/null
    write_build_task "T-9101" "First widget implementation" "[T-9100]" >/dev/null
    write_build_task "T-9102" "Second sprocket implementation" "[T-9100]" >/dev/null
    BUILD=$(write_build_task "T-9103" "Wrapper task" "[T-9100, T-9101, T-9102]")
    run run_check "$BUILD"
    [ "$status" -eq 0 ]
    [[ "$output" == *"all promised deliverables shipped"* ]]
}

@test "Build with missing deliverable — exit 1 with actionable message" {
    write_inception_with_decomposition "T-9110" >/dev/null
    # Only ship B1
    write_build_task "T-9111" "First widget implementation" "[T-9110]" >/dev/null
    BUILD=$(write_build_task "T-9112" "Wrapper" "[T-9110, T-9111]")
    run run_check "$BUILD"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task-pair §ACD gate (P-012)"* ]]
    [[ "$output" == *"sprocket"* ]]
    [[ "$output" == *"--scope-reduction-acknowledged"* ]]
}

@test "Bypass via --scope-reduction-acknowledged — passes with log entry" {
    write_inception_with_decomposition "T-9120" >/dev/null
    BUILD=$(write_build_task "T-9121" "Only first widget" "[T-9120]")
    run run_check "$BUILD" "Out-of-scope, deferred to T-9999"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--scope-reduction-acknowledged bypass"* ]]
    grep -q "scope-reduction-acknowledged" "$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
}

@test "Inception without Decomposition heading — gate is no-op" {
    write_inception_without_decomposition "T-9130" >/dev/null
    BUILD=$(write_build_task "T-9131" "Build under single-deliverable inception" "[T-9130]")
    run run_check "$BUILD"
    [ "$status" -eq 0 ]
    # No "all shipped" message because gate didn't trip at all
    [[ "$output" != *"Task-pair §ACD"* ]]
}

@test "Build with no related_tasks — gate is no-op" {
    BUILD=$(write_build_task "T-9140" "Orphan build" "[]")
    run run_check "$BUILD"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Task-pair §ACD"* ]]
}

@test "Build whose related_tasks point to non-inception — gate is no-op" {
    BUILD2=$(write_build_task "T-9150" "Sibling build" "[]")
    BUILD=$(write_build_task "T-9151" "Build pointing at sibling" "[T-9150]")
    run run_check "$BUILD"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Task-pair §ACD"* ]]
}

@test "Inception (not build) — gate skipped on workflow_type" {
    INC=$(write_inception_with_decomposition "T-9160")
    run run_check "$INC"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Task-pair §ACD"* ]]
}

@test "T-1442/T-1485 historic regression — gate trips on B2+B4 missing" {
    # Real fixtures: T-1485 is a build under T-1442 (Decomposition GO).
    # G-066 verified state: B2 (evidence persistence) + B4 (Layer 2
    # frontmatter) silently dropped. Gate must surface both.
    local saved="$PROJECT_ROOT"
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    BUILD="$FRAMEWORK_ROOT/.tasks/completed/T-1485-reviewer-v15c--fw-reviewer-audit---pass-.md"
    run run_check "$BUILD"
    export PROJECT_ROOT="$saved"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task-pair §ACD"* ]]
    [[ "$output" == *"Evidence persistence"* ]] || [[ "$output" == *"Layer 2"* ]]
}
