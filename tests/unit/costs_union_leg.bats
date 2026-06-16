#!/usr/bin/env bats
# T-2425: lib/costs.sh must union JSONLs across all dirs emitted by
# fw_claude_project_dirs (worktree-aware). Pre-fix it walked ONE dir only,
# leaving `fw costs` blind in worktree sessions where Claude Code's JSONLs
# live under the main-repo dir.
#
# Sibling suites:
#   - tests/unit/t2380_transcript_dir_encoding.bats (T-2380 encoding fix)
#   - tests/unit/budget_gauge_stdin_transcript.bats (T-2377 gauge stdin path)

load ../test_helper

COSTS_LIB="$FRAMEWORK_ROOT/lib/costs.sh"
PATHS_LIB="$FRAMEWORK_ROOT/lib/paths.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # Two fake projects dirs simulating worktree + main-repo case
    export FAKE_HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$FAKE_HOME/.claude/projects/-tmp-worktree"
    mkdir -p "$FAKE_HOME/.claude/projects/-tmp-main"
    # Write one session JSONL in EACH dir to prove union (not just intersection)
    # Use hex-prefixed names because parse_session takes basename[:8] as id
    cat > "$FAKE_HOME/.claude/projects/-tmp-worktree/aaaaaaaa-1111.jsonl" <<EOF
{"timestamp":"2026-06-16T10:00:00Z","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":100,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":50}}}
EOF
    cat > "$FAKE_HOME/.claude/projects/-tmp-main/bbbbbbbb-2222.jsonl" <<EOF
{"timestamp":"2026-06-16T11:00:00Z","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":200,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":75}}}
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "t1: _costs_parse_all unions JSONLs across two candidate dirs" {
    # Inline replacement of fw_claude_project_dirs to emit our two fake dirs.
    run bash -c "
        export HOME='$FAKE_HOME'
        source '$PATHS_LIB'
        source '$COSTS_LIB'
        fw_claude_project_dirs() {
            echo '$FAKE_HOME/.claude/projects/-tmp-worktree'
            echo '$FAKE_HOME/.claude/projects/-tmp-main'
        }
        _costs_parse_all \"\$(fw_claude_project_dirs)\" sessions 2>&1
    "
    [ "$status" -eq 0 ]
    # Both sessions surface (worktree + main) — count hex-prefixed session rows
    [[ "$output" == *"aaaaaaaa"* ]]
    [[ "$output" == *"bbbbbbbb"* ]]
}

@test "t2: single-dir backward compat (only one candidate emits)" {
    run bash -c "
        export HOME='$FAKE_HOME'
        source '$PATHS_LIB'
        source '$COSTS_LIB'
        fw_claude_project_dirs() {
            echo '$FAKE_HOME/.claude/projects/-tmp-worktree'
        }
        _costs_parse_all \"\$(fw_claude_project_dirs)\" sessions 2>&1
    "
    [ "$status" -eq 0 ]
    # Only worktree session surfaces, not main
    [[ "$output" == *"aaaaaaaa"* ]]
    [[ "$output" != *"bbbbbbbb"* ]]
}

@test "t3: no candidate dirs → ERROR with dir list in message" {
    run bash -c "
        export HOME='$FAKE_HOME'
        source '$PATHS_LIB'
        source '$COSTS_LIB'
        fw_claude_project_dirs() {
            echo '/nonexistent/dir-a'
            echo '/nonexistent/dir-b'
        }
        _costs_parse_all \"\$(fw_claude_project_dirs)\" summary 2>&1
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"No JSONL directory found"* ]]
}

@test "t4: dedup by basename — same session id in two dirs counts once" {
    # Put the SAME session basename in both dirs; older should be dropped
    cp "$FAKE_HOME/.claude/projects/-tmp-worktree/aaaaaaaa-1111.jsonl" \
       "$FAKE_HOME/.claude/projects/-tmp-main/aaaaaaaa-1111.jsonl"
    run bash -c "
        export HOME='$FAKE_HOME'
        source '$PATHS_LIB'
        source '$COSTS_LIB'
        fw_claude_project_dirs() {
            echo '$FAKE_HOME/.claude/projects/-tmp-worktree'
            echo '$FAKE_HOME/.claude/projects/-tmp-main'
        }
        _costs_parse_all \"\$(fw_claude_project_dirs)\" sessions 2>&1
    "
    [ "$status" -eq 0 ]
    # session-worktree counted once + session-main = 2 distinct sessions, not 3
    # (count lines that start with a hex session id prefix)
    count=$(echo "$output" | grep -cE "^[0-9a-f]{8}" || true)
    [ "$count" -eq 2 ]
}

@test "t5: _costs_jsonl_dir delegates to fw_claude_project_dirs (newline-separated)" {
    # fw_claude_project_dirs only emits EXISTING dirs. Pre-create the candidate
    # so the delegation path has output to verify.
    local dir_name
    dir_name=$(printf '%s' "$TEST_TEMP_DIR" | tr -c 'a-zA-Z0-9' '-')
    mkdir -p "$FAKE_HOME/.claude/projects/$dir_name"
    run bash -c "
        export PROJECT_ROOT='$TEST_TEMP_DIR'
        export HOME='$FAKE_HOME'
        source '$PATHS_LIB'
        source '$COSTS_LIB'
        _costs_jsonl_dir
    "
    [ "$status" -eq 0 ]
    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -ge 1 ]
    # The output is the canonical-encoded path
    [[ "$output" == *".claude/projects/"* ]]
}
