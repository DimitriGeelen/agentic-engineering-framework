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

    # T-2832: sandbox CONTEXT_DIR too, or this suite writes the LIVE session's focus.
    # PROJECT_ROOT deliberately points at the real repo (template resolution), and
    # create-task.sh --start calls context.sh focus, which writes
    # $CONTEXT_DIR/working/focus.yaml. With CONTEXT_DIR unset that resolved to the
    # real .context/, so a run from inside a live session left it focused on the
    # SANDBOX's first task id (T-001) — absent from the live active/ — after which
    # the check-active-task PreToolUse hook refused every subsequent Bash call.
    # TASKS_DIR alone is not isolation: --start crosses into .context/.
    export CONTEXT_DIR="$TEST_DIR/.context"
    mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project" "$CONTEXT_DIR/episodic"

    # T-100185 hermeticity (L-490 sibling): when this suite runs from inside a
    # Claude Code session it inherits CLAUDECODE=1, which arms the T-2207
    # inception recommendation gate in create-task.sh — the inception-filing
    # tests then fail locally while passing in clean CI. Strip the session env
    # so the suite exercises create-task.sh's own logic, not the caller's
    # environment. The T-2207 gate keeps its own dedicated coverage.
    unset CLAUDECODE FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED

    # T-3141 hermeticity (same class as T-100185 above): when this suite runs
    # inside a TermLink-dispatched worker, FW_SESSION_SCOPED_FOCUS=1 and
    # FW_FOCUS_SESSION_KEY are set in the caller's own environment (T-3038).
    # Inherited here, fw_focus_file() resolves focus.<key>.yaml instead of the
    # plain focus.yaml the T-2832 test below asserts on — a false failure that
    # has nothing to do with create-task.sh's own logic.
    unset FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- T-100185: suite hermeticity vs inherited Claude Code session env ---

@test "T-100185: setup strips inherited CLAUDECODE (hermeticity pin)" {
    # If setup() ever stops unsetting the session env, an inherited
    # CLAUDECODE=1 re-arms the T-2207 inception gate and the 4 inception
    # tests fail locally while passing in clean CI.
    [ -z "${CLAUDECODE:-}" ]
    [ -z "${FW_ALLOW_EMPTY_RECOMMENDATION:-}" ]
}

# --- T-2832: suite hermeticity vs the LIVE session's focus file ---

@test "T-2832: setup sandboxes CONTEXT_DIR (live-focus clobber pin)" {
    # Static half of the pin: CONTEXT_DIR must point inside the sandbox, never at
    # the real repo. If this ever regresses, --start writes the live focus.yaml.
    [ -n "${CONTEXT_DIR:-}" ]
    [[ "$CONTEXT_DIR" == "$TEST_DIR"* ]]
    [[ "$CONTEXT_DIR" != "$FRAMEWORK_ROOT"* ]]
}

@test "T-2832: --start writes focus inside the sandbox, not the live .context" {
    # Behavioural half — the one that actually witnesses the bug. A path
    # assertion alone would stay green if focus.sh started resolving the file
    # some other way, so take the real live file's hash and prove it is untouched
    # by a --start run.
    local live_focus="$FRAMEWORK_ROOT/.context/working/focus.yaml"

    # Precondition: the live file must exist, or "unchanged" is vacuous
    # (T-2828 lesson — a control that cannot fail proves nothing).
    [ -f "$live_focus" ]
    local before
    before="$(md5sum "$live_focus" | cut -d' ' -f1)"

    run "$CREATE_TASK" --name "focus isolation probe" --description "d" \
        --type build --owner agent --start
    [ "$status" -eq 0 ]

    # The sandbox got the focus...
    [ -f "$CONTEXT_DIR/working/focus.yaml" ]
    grep -q "^current_task: T-" "$CONTEXT_DIR/working/focus.yaml"

    # ...and the live session did not.
    local after
    after="$(md5sum "$live_focus" | cut -d' ' -f1)"
    [ "$before" = "$after" ]
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

# --- T-2543: gate-level enforcement for promote-origin creates (Dimitri sovereignty bar) ---

@test "T-2543: promote-origin create with --owner agent is REFUSED at the gate" {
    FW_TASK_ORIGIN=bpmn-promote run timeout 10 "$CREATE_TASK" \
        --name "Promote origin agent" --description "d" --type build --owner agent < /dev/null
    [ "$status" -ne 0 ]
    [ "$status" -ne 124 ]
    [[ "$output" == *"promote-origin"* ]]
    [[ "$output" == *"owner:human"* ]]
    # nothing written
    ! ls "$TEST_DIR/active/" | grep -q "promote-origin-agent"
}

@test "T-2543: promote-origin create with --start is REFUSED at the gate" {
    FW_TASK_ORIGIN=bpmn-promote run timeout 10 "$CREATE_TASK" \
        --name "Promote origin started" --description "d" --type build --owner human --start < /dev/null
    [ "$status" -ne 0 ]
    [ "$status" -ne 124 ]
    [[ "$output" == *"captured"* ]]
}

@test "T-2543: promote-origin create with owner:human + captured is ALLOWED" {
    FW_TASK_ORIGIN=bpmn-promote run timeout 10 "$CREATE_TASK" \
        --name "Promote origin ok" --description "d" --type build --owner human < /dev/null
    [ "$status" -eq 0 ]
    ls "$TEST_DIR/active/" | grep -q "promote-origin-ok"
    grep -q "owner: human" "$TEST_DIR/active/"*promote-origin-ok*.md
    grep -q "status: captured" "$TEST_DIR/active/"*promote-origin-ok*.md
}

@test "T-2543: NON-promote-origin create with --owner agent is UNAFFECTED" {
    run timeout 10 "$CREATE_TASK" \
        --name "Normal agent create" --description "d" --type build --owner agent < /dev/null
    [ "$status" -eq 0 ]
    ls "$TEST_DIR/active/" | grep -q "normal-agent-create"
}
