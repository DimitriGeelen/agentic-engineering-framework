#!/usr/bin/env bats
# T-1431: check-active-task.sh must exempt Claude Code auto-memory paths
# (<home>/.claude/projects/<project>/memory/*.md) regardless of task state.
# These paths live outside PROJECT_ROOT, so the PROJECT_ROOT-anchored exempt
# list doesn't match them. Blocking memory writes defeats the mechanism meant
# to prevent recurrence of problems, and does so exactly when it's most needed
# (mid-onboarding, before T-001-T-005 complete).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    # Simulate an initialized-but-no-focus project (worst case: onboarding)
    mkdir -p "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.tasks/active"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    # No focus.yaml → agent has no active task
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
}

_run_hook_write() {
    local file_path="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path': sys.argv[1]}}))" "$file_path")
    echo "$json" | bash "$HOOK"
}

@test "memory exempt: /root/.claude/projects/<x>/memory/foo.md is allowed without task" {
    run _run_hook_write "/root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/user_role.md"
    [ "$status" -eq 0 ]
}

@test "memory exempt: /home/alice/.claude/projects/<x>/memory/foo.md is allowed (non-root user)" {
    run _run_hook_write "/home/alice/.claude/projects/-home-alice-proj/memory/feedback_testing.md"
    [ "$status" -eq 0 ]
}

@test "memory exempt: MEMORY.md at the root of memory/ is allowed" {
    run _run_hook_write "/root/.claude/projects/-opt-proj/memory/MEMORY.md"
    [ "$status" -eq 0 ]
}

@test "regression: non-memory writes under /root/.claude/ are still blocked without task" {
    # A setting file, not a memory file — must still block.
    run _run_hook_write "/root/.claude/settings.json"
    [ "$status" -eq 2 ]
}

@test "regression: arbitrary outside-project write is still blocked without task" {
    run _run_hook_write "/tmp/random-file.txt"
    [ "$status" -eq 2 ]
}

@test "regression: project-root .context/ write is still allowed (pre-existing exempt)" {
    run _run_hook_write "$PROJECT_ROOT/.context/working/notes.yaml"
    [ "$status" -eq 0 ]
}
