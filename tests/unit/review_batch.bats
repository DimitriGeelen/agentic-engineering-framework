#!/usr/bin/env bats
# Unit tests for emit_review_batch (T-2182 / T-2181 Slice 1)
#
# Covers: markdown table shape, class-correct URL routing per workflow_type,
# zero-args error, unknown-task graceful NOT-FOUND row.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/review.sh"

    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.context/working"

    # Force a deterministic base URL — explicit env override (Layer 0 fast-path
    # in _watchtower_url; bypasses triple-file pid/identity probing).
    export WATCHTOWER_URL="http://test-host:7777"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_task() {
    local task_id="$1"
    local workflow="${2:-build}"
    local file="$TEST_TEMP_DIR/.tasks/active/${task_id}-test.md"
    # T-2206: inception fixtures need a substantive ## Recommendation; otherwise
    # emit_review_batch's Slice C pre-pass refuses the entire batch.
    local rec_block=""
    if [ "$workflow" = "inception" ]; then
        rec_block=$'\n## Recommendation\n\n**Recommendation:** GO\n**Rationale:** test fixture\n'
    fi
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test task"
status: started-work
workflow_type: ${workflow}
owner: agent
---

# ${task_id}: Test task
${rec_block}
EOF
}

@test "emit_review_batch: zero args returns 1 and prints usage" {
    run emit_review_batch
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires ≥1 task ID"* ]]
}

@test "emit_review_batch: single build task emits /review/ URL row" {
    _make_task T-100 build
    run emit_review_batch T-100
    [ "$status" -eq 0 ]
    [[ "$output" == *"| Task | Workflow | Link |"* ]]
    [[ "$output" == *"|------|----------|------|"* ]]
    [[ "$output" == *"| T-100 | build | http://test-host:7777/review/T-100 |"* ]]
}

@test "emit_review_batch: inception task emits /inception/ URL row" {
    _make_task T-200 inception
    run emit_review_batch T-200
    [ "$status" -eq 0 ]
    [[ "$output" == *"| T-200 | inception | http://test-host:7777/inception/T-200 |"* ]]
}

@test "emit_review_batch: mixed batch emits class-correct URLs per task" {
    _make_task T-101 build
    _make_task T-201 inception
    _make_task T-102 build
    run emit_review_batch T-101 T-201 T-102
    [ "$status" -eq 0 ]
    [[ "$output" == *"| T-101 | build | http://test-host:7777/review/T-101 |"* ]]
    [[ "$output" == *"| T-201 | inception | http://test-host:7777/inception/T-201 |"* ]]
    [[ "$output" == *"| T-102 | build | http://test-host:7777/review/T-102 |"* ]]
}

@test "emit_review_batch: unknown task emits NOT-FOUND row, does not crash" {
    _make_task T-103 build
    run emit_review_batch T-103 T-9999
    [ "$status" -eq 0 ]
    [[ "$output" == *"| T-103 | build | http://test-host:7777/review/T-103 |"* ]]
    [[ "$output" == *"| T-9999 | ? | NOT-FOUND |"* ]]
}

@test "emit_review_batch: completed/ task resolves correctly" {
    local file="$TEST_TEMP_DIR/.tasks/completed/T-300-completed.md"
    cat > "$file" <<EOF
---
id: T-300
name: "Closed task"
status: work-completed
workflow_type: build
owner: agent
---
EOF
    run emit_review_batch T-300
    [ "$status" -eq 0 ]
    [[ "$output" == *"| T-300 | build | http://test-host:7777/review/T-300 |"* ]]
}

@test "emit_review_batch: emits table header exactly once even for N tasks" {
    _make_task T-104 build
    _make_task T-105 build
    _make_task T-106 build
    run emit_review_batch T-104 T-105 T-106
    [ "$status" -eq 0 ]
    local header_count
    header_count=$(echo "$output" | grep -c "| Task | Workflow | Link |")
    [ "$header_count" -eq 1 ]
}
