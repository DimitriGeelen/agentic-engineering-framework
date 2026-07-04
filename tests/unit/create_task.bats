#!/usr/bin/env bats
# Unit tests for agents/task-create/create-task.sh
# Origin: T-921

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CREATE_TASK="$FRAMEWORK_ROOT/agents/task-create/create-task.sh"

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_DIR="$BATS_TMPDIR/fw_create_task_test_$$"
    mkdir -p "$TEST_DIR/active" "$TEST_DIR/completed" "$TEST_DIR/templates"

    # Copy the default template
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_DIR/templates/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TEST_DIR/templates/default.md" 2>/dev/null || true

    # Override TASKS_DIR for testing
    export TASKS_DIR="$TEST_DIR"
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- T-100160 (OBS-086): no-tty fail-fast instead of hanging prompts ---

@test "T-100160: non-tty + missing required flags fails fast naming them (no hang)" {
    # bats runs with stdin not a tty; before the fix this blocked forever on
    # the interactive prompt (observed: 2 fw task create hangs >1h, 2026-07-04).
    run timeout 10 "$CREATE_TASK" --name "No tty probe" --description "d" --type build < /dev/null
    [ "$status" -ne 0 ]
    [ "$status" -ne 124 ]  # not the timeout — the script itself refused
    [[ "$output" == *"--owner"* ]]
    [[ "$output" == *"not a tty"* ]]
}

@test "T-100160: non-tty with ALL required flags still creates the task" {
    run timeout 10 "$CREATE_TASK" --name "No tty full flags" --description "d" --type build --owner agent < /dev/null
    [ "$status" -eq 0 ]
    ls "$TEST_DIR/active/" | grep -q "no-tty-full-flags"
}

@test "T-100160: tty prompt path preserved (guard precedes prompts, is tty-conditioned)" {
    # A real-pty test is racy under bats; pin the structure instead: the
    # no-tty guard sits BEFORE the first interactive prompt and fires only
    # when stdin is not a tty — the tty prompt fallback is untouched.
    guard_line=$(grep -n '\[ ! -t 0 \]' "$CREATE_TASK" | head -1 | cut -d: -f1)
    first_prompt=$(grep -n 'read -r NAME' "$CREATE_TASK" | head -1 | cut -d: -f1)
    [ -n "$guard_line" ] && [ -n "$first_prompt" ]
    [ "$guard_line" -lt "$first_prompt" ]
    grep -q 'read -r OWNER' "$CREATE_TASK"
}

# --- Help ---

@test "create-task --help shows usage" {
    run "$CREATE_TASK" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--name"* ]]
    [[ "$output" == *"--type"* ]]
}

# --- Placeholder rejection (T-555) ---

@test "rejects 'task name' placeholder" {
    run "$CREATE_TASK" --name "task name" --description "test" --type build --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"placeholder"* ]]
}

@test "rejects 'Task Name' placeholder (case insensitive)" {
    run "$CREATE_TASK" --name "Task Name" --description "test" --type build --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"placeholder"* ]]
}

@test "rejects 'fix bug' placeholder" {
    run "$CREATE_TASK" --name "fix bug" --description "test" --type build --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"placeholder"* ]]
}

@test "accepts real task name" {
    run "$CREATE_TASK" --name "Fix login timeout on slow connections" --description "test" --type build --owner agent
    # Should not get placeholder error (may succeed or fail for other reasons)
    if [ "$status" -ne 0 ]; then
        [[ "$output" != *"placeholder"* ]]
    fi
}

# --- Invalid workflow type ---

@test "rejects invalid workflow type" {
    run "$CREATE_TASK" --name "Test task name" --description "test" --type invalid_type --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"Valid types"* ]]
}

# --- Invalid horizon ---

@test "rejects invalid horizon" {
    run "$CREATE_TASK" --name "Test task name" --description "test" --type build --owner agent --horizon invalid
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"horizon"* ]]
}

# --- Unknown option ---

@test "rejects unknown option" {
    run "$CREATE_TASK" --unknown-flag
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown"* ]]
}

# --- Task creation (integration) ---

@test "creates task file with correct fields" {
    run "$CREATE_TASK" --name "Unit test task creation" --description "Testing create-task" --type build --owner agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task Created"* ]]
    [[ "$output" == *"T-"* ]]

    # Verify file was created
    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    [ -n "$task_file" ]

    # Check frontmatter
    grep -q "^id: T-" "$task_file"
    grep -q 'name:.*Unit test task creation' "$task_file"
    grep -q "^workflow_type: build" "$task_file"
    grep -q "^owner: agent" "$task_file"
}

@test "creates task with tags" {
    run "$CREATE_TASK" --name "Tagged test task" --description "Testing tags" --type build --owner agent --tags "ui,api"
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    grep -q "tags:.*ui.*api" "$task_file"
}

@test "creates task with horizon later" {
    run "$CREATE_TASK" --name "Deferred test task" --description "Testing horizon" --type build --owner agent --horizon later
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    grep -q "^horizon: later" "$task_file"
}

@test "creates task with --start flag" {
    run "$CREATE_TASK" --name "Started test task" --description "Testing start flag" --type build --owner agent --start
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    grep -q "^status: started-work" "$task_file"
}

@test "creates inception task from inception template" {
    # Copy inception template if it exists
    if [ -f "$FRAMEWORK_ROOT/.tasks/templates/inception.md" ]; then
        cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$TEST_DIR/templates/"
    fi

    run "$CREATE_TASK" --name "Inception: evaluate caching" --description "Testing inception" --type inception --owner agent
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    grep -q "^workflow_type: inception" "$task_file"
}

# --- ID generation ---

@test "generates sequential IDs" {
    # Create first task
    "$CREATE_TASK" --name "First sequential task" --description "test" --type build --owner agent
    local first_file
    first_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    local first_id
    first_id=$(grep '^id:' "$first_file" | sed 's/id: *//')

    # Create second task
    "$CREATE_TASK" --name "Second sequential task" --description "test" --type build --owner agent
    local files
    files=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | wc -l)
    [ "$files" -eq 2 ]
}

# --- Slug generation ---

@test "slug converts to lowercase" {
    run "$CREATE_TASK" --name "UPPERCASE Name Test" --description "test" --type build --owner agent
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    local filename
    filename=$(basename "$task_file")
    # Filename should be lowercase
    [[ "$filename" == *"uppercase-name-test"* ]]
}

@test "slug replaces spaces with hyphens" {
    run "$CREATE_TASK" --name "Space separated name" --description "test" --type build --owner agent
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    local filename
    filename=$(basename "$task_file")
    [[ "$filename" == *"space-separated-name"* ]]
}

@test "slug truncates long names" {
    run "$CREATE_TASK" --name "This is a very long task name that should definitely be truncated by the slug generator" --description "test" --type build --owner agent
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    local filename
    filename=$(basename "$task_file")
    # Slug part should be max 40 chars (T-XXX- prefix + slug)
    local slug_part
    slug_part=$(echo "$filename" | sed 's/^T-[0-9]*-//' | sed 's/\.md$//')
    [ "${#slug_part}" -le 40 ]
}

# --- T-1263: Inception template section validation ---

@test "inception task has Recommendation and Decision sections" {
    # Copy inception template
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$TEST_DIR/templates/"
    run "$CREATE_TASK" --name "Test inception sections" --description "test" --type inception --owner agent
    [ "$status" -eq 0 ]

    local task_file
    task_file=$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null | head -1)
    [ -n "$task_file" ]
    grep -q '^## Recommendation' "$task_file"
    grep -q '^## Decision' "$task_file"
}

@test "inception task fails when template lacks Recommendation section" {
    # Create a broken inception template without ## Recommendation
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$TEST_DIR/templates/"
    sed -i '/^## Recommendation/,/^## /{ /^## Recommendation/d; /^## [^R]/!d; }' "$TEST_DIR/templates/inception.md"

    run "$CREATE_TASK" --name "Test broken template" --description "test" --type inception --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"Inception template missing required sections"* ]]
    [[ "$output" == *"Recommendation"* ]]
    # Task file should have been cleaned up
    [ -z "$(ls "$TEST_DIR/active/T-"*.md 2>/dev/null)" ]
}

@test "inception task fails when template lacks Decision section" {
    # Create a broken inception template without ## Decision
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$TEST_DIR/templates/"
    sed -i '/^## Decision$/d' "$TEST_DIR/templates/inception.md"

    run "$CREATE_TASK" --name "Test broken template 2" --description "test" --type inception --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"Inception template missing required sections"* ]]
    [[ "$output" == *"Decision"* ]]
}
