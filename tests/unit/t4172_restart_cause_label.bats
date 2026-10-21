#!/usr/bin/env bats
# T-4172 (dimitri-mint-dev P-010) — the recovery block names the real cause of
# the new session, and the handover it restores from.
#
# T-4353 split the header by SessionStart source, but a budget restart under
# FW_RESTART_MODE=continue relaunches with `--resume <id>`, which arrives as
# source `resume` beside claude-fw's .auto-restart-pending sentinel. The hook
# only read the sentinel on `startup`, so that budget restart was labelled a
# plain resume and the sentinel was left behind. No header named the handover.

load ../test_helper

export CLAUDE_FW_NO_SIDECAR=1
export FW_WATCHTOWER_ENSURE=0

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    mkdir -p "$TEST_TEMP_DIR/.claude" "$TEST_TEMP_DIR/.context/working" \
             "$TEST_TEMP_DIR/.context/handovers" "$TEST_TEMP_DIR/.tasks/active" \
             "$TEST_TEMP_DIR/.tasks/completed" "$TEST_TEMP_DIR/.tasks/templates"
    cat > "$TEST_TEMP_DIR/.framework.yaml" <<EOF
framework_root: $FRAMEWORK_ROOT
EOF
    cat > "$TEST_TEMP_DIR/.context/handovers/LATEST.md" <<'EOF'
---
session_id: S-2026-1013-0101
---
# Session Handover: S-2026-1013-0101
## Where We Are
Test fixture
## Work in Progress
none
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run the real hook for a source; print the injected additionalContext.
context_for() {
    cd "$TEST_TEMP_DIR"
    printf '{"source":"%s","session_id":"t4172"}' "$1" \
        | PROJECT_ROOT="$TEST_TEMP_DIR" FW_WATCHTOWER_ENSURE=0 \
          bash "$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh" 2>/dev/null \
        | python3 -c '
import json, sys
print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
'
}

@test "resume with a fresh restart sentinel is labelled a budget auto-restart" {
    : > "$TEST_TEMP_DIR/.context/working/.auto-restart-pending"
    run context_for resume
    [ "$status" -eq 0 ]
    header=$(printf '%s\n' "$output" | grep -m1 .)
    [[ "$header" == *"Auto-Restart"* ]]
    [[ "$output" != *"Post-Compaction"* ]]
    [[ "$output" == *"budget"* ]]
    [[ "$output" != *"Resumed session (claude -c or /resume)"* ]]
}

@test "resume consumes the restart sentinel" {
    : > "$TEST_TEMP_DIR/.context/working/.auto-restart-pending"
    run context_for resume
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_TEMP_DIR/.context/working/.auto-restart-pending" ]
}

@test "plain resume (no sentinel) keeps the resume header — control leg" {
    run context_for resume
    [ "$status" -eq 0 ]
    header=$(printf '%s\n' "$output" | grep -m1 .)
    [[ "$header" == *"Session Resume"* ]]
    [[ "$header" != *"Auto-Restart"* ]]
}

@test "resume with a stale sentinel is a plain resume" {
    : > "$TEST_TEMP_DIR/.context/working/.auto-restart-pending"
    touch -d '1 hour ago' "$TEST_TEMP_DIR/.context/working/.auto-restart-pending"
    run context_for resume
    [ "$status" -eq 0 ]
    header=$(printf '%s\n' "$output" | grep -m1 .)
    [[ "$header" == *"Session Resume"* ]]
}

@test "auto-restart header names the handover it restores from" {
    : > "$TEST_TEMP_DIR/.context/working/.auto-restart-pending"
    run context_for startup
    [ "$status" -eq 0 ]
    [[ "$output" == *"S-2026-1013-0101"* ]]
}

@test "resume header names the handover it restores from" {
    run context_for resume
    [ "$status" -eq 0 ]
    [[ "$output" == *"S-2026-1013-0101"* ]]
}
