#!/usr/bin/env bats
# T-4353 (GH #96) — the SessionStart resume hook must not claim a compaction
# that never happened.
#
# post-compact-resume.sh fires on three SessionStart sources: `compact`
# (/compact), `resume` (claude -c, /resume) and `startup` (claude-fw budget
# auto-restart, gated by the .auto-restart-pending sentinel). Its context
# header used to read "Post-Compaction Context Recovery" for all three, so after
# a fresh auto-restart the agent reported a compaction to the operator.
# These tests run the real hook once per source and read the header it injects.

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
session_id: test
---
# Session Handover: test
## Where We Are
Test fixture
## Work in Progress
none
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run the real hook for a SessionStart source; print the first line of the
# injected additionalContext (the header).
header_for() {
    local src="$1"
    [ "$src" = "startup" ] && : > "$TEST_TEMP_DIR/.context/working/.auto-restart-pending"
    cd "$TEST_TEMP_DIR"
    printf '{"source":"%s","session_id":"t4353"}' "$src" \
        | PROJECT_ROOT="$TEST_TEMP_DIR" FW_WATCHTOWER_ENSURE=0 \
          bash "$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh" 2>/dev/null \
        | python3 -c '
import json, sys
d = json.load(sys.stdin)
ctx = d["hookSpecificOutput"]["additionalContext"]
print(next(l for l in ctx.splitlines() if l.strip()))
'
}

@test "compact keeps the Post-Compaction header — control leg" {
    run header_for compact
    [ "$status" -eq 0 ]
    [[ "$output" == *"Post-Compaction Context Recovery"* ]]
}

@test "startup (auto-restart) does not claim a compaction" {
    run header_for startup
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" != *"Post-Compaction"* ]]
    [[ "$output" == *"Auto-Restart"* ]]
}

@test "resume (claude -c) does not claim a compaction" {
    run header_for resume
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" != *"Post-Compaction"* ]]
    [[ "$output" == *"Resume"* ]]
}

@test "startup context states plainly that no compaction happened" {
    : > "$TEST_TEMP_DIR/.context/working/.auto-restart-pending"
    cd "$TEST_TEMP_DIR"
    out=$(printf '{"source":"startup"}' \
        | PROJECT_ROOT="$TEST_TEMP_DIR" FW_WATCHTOWER_ENSURE=0 \
          bash "$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh" 2>/dev/null)
    echo "$out" | grep -q "No compaction happened"
}
