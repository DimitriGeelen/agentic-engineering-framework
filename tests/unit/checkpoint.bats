#!/usr/bin/env bats
# Unit tests for agents/context/checkpoint.sh
#
# Tests transcript discovery scoping (T-791) and status output

load ../test_helper

CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.context/working"

    # Override HOME so we control .claude/projects/
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: create a fake JSONL transcript with token data.
# T-2885: writes TWO usage entries (same model) — the dominant-model scope
# requires >=2 in-scope entries before it will report a reading at all.
_create_transcript() {
    local dir="$1"
    local tokens="$2"
    local filename="${3:-test-session.jsonl}"
    mkdir -p "$dir"
    # Write two fake API response entries with usage data (last one wins)
    cat > "$dir/$filename" <<EOF
{"message":{"model":"claude-opus-4-6","usage":{"input_tokens":$tokens,"output_tokens":500,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"message":{"model":"claude-opus-4-6","usage":{"input_tokens":$tokens,"output_tokens":500,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
EOF
    echo "$dir/$filename"
}

# --- Status output ---

@test "checkpoint: status shows tool call count" {
    echo "5" > "$PROJECT_ROOT/.context/working/.tool-counter"
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Tool calls since last commit: 5"* ]]
}

@test "checkpoint: status shows unavailable when no transcript" {
    echo "0" > "$PROJECT_ROOT/.context/working/.tool-counter"
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"unavailable"* ]]
}

# --- Transcript scoping (T-791) ---

@test "checkpoint: finds transcript in current project directory" {
    echo "0" > "$PROJECT_ROOT/.context/working/.tool-counter"
    # Create project-specific Claude directory
    local project_dir_name
    project_dir_name=$(echo "$PROJECT_ROOT" | sed 's|/|-|g')
    _create_transcript "$HOME/.claude/projects/${project_dir_name}" 50000
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"50000"* ]]
}

@test "checkpoint: ignores transcripts from other projects" {
    echo "0" > "$PROJECT_ROOT/.context/working/.tool-counter"
    # Create transcript for a DIFFERENT project with high tokens
    _create_transcript "$HOME/.claude/projects/-opt-other-project" 185000
    # No transcript for THIS project
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    # Should NOT report 185000 — should report unavailable
    [[ "$output" != *"185000"* ]]
    [[ "$output" == *"unavailable"* ]]
}

@test "checkpoint: reads correct project when multiple exist" {
    echo "0" > "$PROJECT_ROOT/.context/working/.tool-counter"
    local project_dir_name
    project_dir_name=$(echo "$PROJECT_ROOT" | sed 's|/|-|g')
    # Create transcript for THIS project (50K)
    _create_transcript "$HOME/.claude/projects/${project_dir_name}" 50000
    # Create transcript for OTHER project (185K) — more recently modified
    sleep 1
    _create_transcript "$HOME/.claude/projects/-opt-other-project" 185000
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    # Must report THIS project's 50K, not other project's 185K
    [[ "$output" == *"50000"* ]]
    [[ "$output" != *"185000"* ]]
}

# --- T-1088: Session-start-ts filter (post-compact JSONL scan) ---

# Helper: create a transcript with three entries: one pre-session-start
# timestamp (simulates pre-compact final usage) and TWO post-session-start
# entries (simulates post-compact) — same model throughout. T-2885: the
# dominant-model scope needs >=2 in-scope entries to report a reading, so a
# single post-ts entry would otherwise return 0 regardless of the T-1088
# filter working correctly.
_create_timestamped_transcript() {
    local dir="$1"
    local filename="${2:-test-session.jsonl}"
    mkdir -p "$dir"
    cat > "$dir/$filename" <<'EOF'
{"timestamp":"2026-04-11T09:00:00.000Z","message":{"model":"claude-opus-4-6","usage":{"input_tokens":296000,"output_tokens":500,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"timestamp":"2026-04-11T10:30:00.000Z","message":{"model":"claude-opus-4-6","usage":{"input_tokens":40000,"output_tokens":500,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"timestamp":"2026-04-11T11:00:00.000Z","message":{"model":"claude-opus-4-6","usage":{"input_tokens":50000,"output_tokens":500,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
EOF
    echo "$dir/$filename"
}

@test "checkpoint: T-1088 filters pre-session-start JSONL entries" {
    echo "0" > "$PROJECT_ROOT/.context/working/.tool-counter"
    local project_dir_name
    project_dir_name=$(echo "$PROJECT_ROOT" | sed 's|/|-|g')
    _create_timestamped_transcript "$HOME/.claude/projects/${project_dir_name}"
    # Session starts between the two entries — only the 50000 entry counts.
    echo "2026-04-11T10:00:00.000Z" > "$PROJECT_ROOT/.context/working/.session-start-ts"
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"50000"* ]]
    [[ "$output" != *"296000"* ]]
}

@test "checkpoint: T-1088 without session-start-ts uses all entries (backward compat)" {
    echo "0" > "$PROJECT_ROOT/.context/working/.tool-counter"
    local project_dir_name
    project_dir_name=$(echo "$PROJECT_ROOT" | sed 's|/|-|g')
    _create_timestamped_transcript "$HOME/.claude/projects/${project_dir_name}"
    # No .session-start-ts file — loop should pick the last entry (50000).
    [ ! -f "$PROJECT_ROOT/.context/working/.session-start-ts" ]
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"50000"* ]]
}

@test "checkpoint: T-1088 session-start-ts AFTER all entries yields 0 tokens" {
    echo "0" > "$PROJECT_ROOT/.context/working/.tool-counter"
    local project_dir_name
    project_dir_name=$(echo "$PROJECT_ROOT" | sed 's|/|-|g')
    _create_timestamped_transcript "$HOME/.claude/projects/${project_dir_name}"
    # Session start is AFTER both entries — nothing should count.
    echo "2026-04-11T12:00:00.000Z" > "$PROJECT_ROOT/.context/working/.session-start-ts"
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    [[ "$output" != *"296000"* ]]
    [[ "$output" != *"50000"* ]]
}

# --- Reset ---

@test "checkpoint: reset clears counter and prev-tokens" {
    echo "42" > "$PROJECT_ROOT/.context/working/.tool-counter"
    echo "150000" > "$PROJECT_ROOT/.context/working/.prev-token-reading"
    touch "$PROJECT_ROOT/.context/working/.restart-requested"
    run "$CHECKPOINT" reset
    [ "$status" -eq 0 ]
    [ "$(cat "$PROJECT_ROOT/.context/working/.tool-counter")" = "0" ]
    [ ! -f "$PROJECT_ROOT/.context/working/.prev-token-reading" ]
    [ ! -f "$PROJECT_ROOT/.context/working/.restart-requested" ]
}

# --- Usage ---

@test "checkpoint: invalid subcommand shows usage" {
    run "$CHECKPOINT" bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

# --- Agent transcript filtering ---

@test "checkpoint: ignores agent-prefixed transcript files" {
    echo "0" > "$PROJECT_ROOT/.context/working/.tool-counter"
    local project_dir_name
    project_dir_name=$(echo "$PROJECT_ROOT" | sed 's|/|-|g')
    local dir="$HOME/.claude/projects/${project_dir_name}"
    mkdir -p "$dir"
    # Create an agent transcript (should be ignored)
    cat > "$dir/agent-abc123.jsonl" <<EOF
{"message":{"model":"claude-opus-4-6","usage":{"input_tokens":99999,"output_tokens":500}}}
EOF
    run "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"unavailable"* ]]
}
