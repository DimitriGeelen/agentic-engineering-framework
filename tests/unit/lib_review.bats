#!/usr/bin/env bats
# Unit tests for lib/review.sh
#
# Tests emit_review() — human review output helper

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/review.sh"

    # Create task directory structure
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_create_review_task() {
    local task_id="${1:-T-999}"
    local workflow="${2:-build}"
    local file="$TEST_TEMP_DIR/.tasks/active/${task_id}-test.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test task"
status: work-completed
workflow_type: ${workflow}
owner: human
---

# ${task_id}: Test task

## Acceptance Criteria

### Agent
- [x] Agent criterion done

### Human
- [ ] First human AC
- [x] Second human AC checked
- [ ] Third human AC
EOF
    echo "$file"
}

@test "review: emit_review returns 1 on empty task_id" {
    run emit_review ""
    [ "$status" -eq 1 ]
}

@test "review: emit_review returns 1 on missing task file" {
    run emit_review "T-000"
    [ "$status" -eq 1 ]
}

@test "review: emit_review outputs review header for build task" {
    local task_file
    task_file=$(_create_review_task "T-100" "build")
    run emit_review "T-100" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-100"* ]]
    [[ "$output" == *"Human AC Review"* ]]
}

@test "review: emit_review outputs inception review for inception task" {
    local task_file
    task_file=$(_create_review_task "T-200" "inception")
    run emit_review "T-200" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-200"* ]]
    [[ "$output" == *"Inception Review"* ]]
}

@test "review: emit_review counts human ACs correctly" {
    local task_file
    task_file=$(_create_review_task "T-300" "build")
    run emit_review "T-300" "$task_file"
    [ "$status" -eq 0 ]
    # 1 checked out of 3 total
    [[ "$output" == *"1/3"* ]]
}

@test "review: emit_review finds task file by ID" {
    _create_review_task "T-400" "build"
    run emit_review "T-400"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-400"* ]]
}

@test "review: emit_review includes Watchtower URL" {
    local task_file
    task_file=$(_create_review_task "T-500" "build")
    run emit_review "T-500" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"http"* ]]
    [[ "$output" == *"/review/T-500"* ]]
}

@test "review: emit_review uses inception URL for inception tasks" {
    local task_file
    task_file=$(_create_review_task "T-600" "inception")
    run emit_review "T-600" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/inception/T-600"* ]]
}

@test "review: emit_review handles task with zero human ACs" {
    local file="$TEST_TEMP_DIR/.tasks/active/T-700-test.md"
    cat > "$file" <<EOF
---
id: T-700
name: "No human ACs"
workflow_type: build
---

# T-700: No human ACs

## Acceptance Criteria

### Agent
- [x] Only agent criteria
EOF
    run emit_review "T-700" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0/0"* ]]
}

@test "review: emit_review respects WATCHTOWER_URL env var" {
    export WATCHTOWER_URL="http://custom:8080"
    local task_file
    task_file=$(_create_review_task "T-800" "build")
    run emit_review "T-800" "$task_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"http://custom:8080/review/T-800"* ]]
    unset WATCHTOWER_URL
}
