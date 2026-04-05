#!/usr/bin/env bats
# Unit tests for agents/resume/resume.sh
# Origin: T-922

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
RESUME="$FRAMEWORK_ROOT/agents/resume/resume.sh"

# --- Help and routing ---

@test "resume --help shows usage" {
    run "$RESUME" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Resume Agent"* ]]
    [[ "$output" == *"status"* ]]
    [[ "$output" == *"sync"* ]]
    [[ "$output" == *"quick"* ]]
}

@test "resume help shows usage" {
    run "$RESUME" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Resume Agent"* ]]
}

@test "resume with no args shows help" {
    run "$RESUME" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"Resume Agent"* ]]
}

@test "resume unknown command fails" {
    run "$RESUME" nonexistent
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown"* ]]
}

# --- Quick command ---

@test "resume quick produces output" {
    run "$RESUME" quick
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "resume quick shows focus or task count" {
    run "$RESUME" quick
    [ "$status" -eq 0 ]
    # Should contain either "Focus:", "active tasks", or "No active tasks"
    [[ "$output" == *"Focus"* ]] || [[ "$output" == *"tasks"* ]] || [[ "$output" == *"project"* ]]
}

# --- Status command ---

@test "resume status produces structured output" {
    run "$RESUME" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESUME"* ]] || [[ "$output" == *"Current State"* ]]
}

@test "resume status shows git info" {
    run "$RESUME" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git"* ]]
    [[ "$output" == *"Branch"* ]]
}

@test "resume status shows active tasks" {
    run "$RESUME" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Active Tasks"* ]]
}

@test "resume status shows recommendations" {
    run "$RESUME" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Recommendations"* ]] || [[ "$output" == *"Suggested"* ]]
}

# --- Sync command ---

@test "resume sync produces output" {
    run "$RESUME" sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sync"* ]]
}

@test "resume sync validates focus" {
    run "$RESUME" sync
    [ "$status" -eq 0 ]
    # Should either confirm focus or report no session
    [[ "$output" == *"focus"* ]] || [[ "$output" == *"Focus"* ]] || [[ "$output" == *"session"* ]] || [[ "$output" == *"Sync"* ]]
}
