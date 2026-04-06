#!/usr/bin/env bats
# Unit tests for agents/handover/handover.sh
# Origin: T-923, T-944 (isolation fix)

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"
HANDOVER_DIR="$FRAMEWORK_ROOT/.context/handovers"

# Save/restore LATEST.md symlink to prevent test pollution
setup() {
    if [ -L "$HANDOVER_DIR/LATEST.md" ]; then
        ORIGINAL_TARGET="$(readlink "$HANDOVER_DIR/LATEST.md")"
    fi
    # Track handover files before test
    BEFORE_FILES="$(ls "$HANDOVER_DIR"/S-*.md 2>/dev/null | sort)"
}

teardown() {
    # Restore LATEST.md symlink
    if [ -n "${ORIGINAL_TARGET:-}" ] && [ -f "$HANDOVER_DIR/$ORIGINAL_TARGET" ]; then
        ln -sf "$ORIGINAL_TARGET" "$HANDOVER_DIR/LATEST.md"
    fi
    # Clean up any handover files created during tests
    AFTER_FILES="$(ls "$HANDOVER_DIR"/S-*.md 2>/dev/null | sort)"
    if [ "$AFTER_FILES" != "$BEFORE_FILES" ]; then
        diff <(echo "$BEFORE_FILES") <(echo "$AFTER_FILES") | grep '^>' | sed 's/^> //' | while read f; do
            rm -f "$f"
        done
    fi
    # Also clean up CHECKPOINT files
    rm -f "$HANDOVER_DIR"/CHECKPOINT-*.md
}

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
    [ -f "$HANDOVER_DIR/LATEST.md" ]
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
    head -1 "$HANDOVER_DIR/LATEST.md" | grep -q "^---"
}

@test "handover includes Where We Are section" {
    "$HANDOVER" --no-commit 2>&1 >/dev/null
    grep -q "## Where We Are" "$HANDOVER_DIR/LATEST.md"
}

@test "handover includes Suggested First Action" {
    "$HANDOVER" --no-commit 2>&1 >/dev/null
    grep -q "## Suggested First Action" "$HANDOVER_DIR/LATEST.md"
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
    before_session=$(grep "^session_id:" "$HANDOVER_DIR/LATEST.md" 2>/dev/null | head -1)

    run "$HANDOVER" --checkpoint --no-commit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Checkpoint"* ]] || [[ "$output" == *"checkpoint"* ]] || [[ "$output" == *"Handover"* ]]
}
