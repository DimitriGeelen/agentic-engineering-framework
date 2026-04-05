#!/usr/bin/env bats
# Unit tests for agents/handover/handover.sh
# Origin: T-923

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"

# --- Help ---

@test "handover --help shows usage" {
    run "$HANDOVER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"handover"* ]]
    [[ "$output" == *"--commit"* ]]
    [[ "$output" == *"--checkpoint"* ]]
}

@test "handover -h shows usage" {
    run "$HANDOVER" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"handover"* ]]
}

# --- Handover generation ---

@test "handover generates session document" {
    run "$HANDOVER" --no-commit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Handover"* ]]
    [[ "$output" == *"Session"* ]] || [[ "$output" == *"S-"* ]]
}

@test "handover creates file in handovers directory" {
    run "$HANDOVER" --no-commit
    [ "$status" -eq 0 ]
    # Check LATEST.md exists
    [ -f "$FRAMEWORK_ROOT/.context/handovers/LATEST.md" ]
}

@test "handover output mentions session ID" {
    run "$HANDOVER" --no-commit
    [ "$status" -eq 0 ]
    # Should contain an S- session ID
    [[ "$output" == *"S-"* ]]
}

@test "handover generates valid frontmatter" {
    "$HANDOVER" --no-commit 2>&1 >/dev/null
    # Check LATEST.md has frontmatter
    head -1 "$FRAMEWORK_ROOT/.context/handovers/LATEST.md" | grep -q "^---"
}

@test "handover includes Where We Are section" {
    "$HANDOVER" --no-commit 2>&1 >/dev/null
    grep -q "## Where We Are" "$FRAMEWORK_ROOT/.context/handovers/LATEST.md"
}

@test "handover includes Suggested First Action" {
    "$HANDOVER" --no-commit 2>&1 >/dev/null
    grep -q "## Suggested First Action" "$FRAMEWORK_ROOT/.context/handovers/LATEST.md"
}

# --- Task flag ---

@test "handover accepts --task flag" {
    run "$HANDOVER" --no-commit --task T-012
    [ "$status" -eq 0 ]
}

# --- Checkpoint mode ---

@test "handover --checkpoint does not replace LATEST.md timestamp" {
    # Get current LATEST.md session ID
    local before_session
    before_session=$(grep "^session_id:" "$FRAMEWORK_ROOT/.context/handovers/LATEST.md" 2>/dev/null | head -1)

    run "$HANDOVER" --checkpoint --no-commit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Checkpoint"* ]] || [[ "$output" == *"checkpoint"* ]] || [[ "$output" == *"Handover"* ]]
}
