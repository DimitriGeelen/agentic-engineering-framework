#!/usr/bin/env bats
# T-5348 (G-139 cause B): the harness shows only about the first 2KB of the SessionStart
# injection. The T-1728 budget note was appended last (byte 111,887 of 112,928 in the
# session that found this), so a resumed agent never saw it and repeated a stop
# recommendation made at ~750K while the gauge read Green at 260K.
# These tests run the real hook per source and assert the short note is in the first 2000
# bytes, before "## Where We Are", and names what is stale and where the live band is.

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
    printf 'framework_root: %s\n' "$FRAMEWORK_ROOT" > "$TEST_TEMP_DIR/.framework.yaml"
    # A long handover, so a note placed after it would fall past 2000 bytes.
    {
        printf -- '---\nsession_id: test\n---\n# Session Handover: test\n## Where We Are\n'
        for i in $(seq 1 200); do printf 'Budget at 92%%, stopping new work (line %d)\n' "$i"; done
        printf '## Work in Progress\nnone\n'
    } > "$TEST_TEMP_DIR/.context/handovers/LATEST.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

context_for() {
    local src="$1"
    [ "$src" = "startup" ] && : > "$TEST_TEMP_DIR/.context/working/.auto-restart-pending"
    cd "$TEST_TEMP_DIR"
    printf '{"source":"%s","session_id":"t5348"}' "$src" \
        | PROJECT_ROOT="$TEST_TEMP_DIR" FW_WATCHTOWER_ENSURE=0 \
          bash "$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh" 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'
}

assert_note_visible() {
    local ctx="$1" head
    head=$(printf '%s' "$ctx" | head -c 2000)
    [[ "$head" == *"Budget (T-5348)"* ]] || { echo "note not in first 2000 bytes"; false; }
    [[ "$head" == *"compaction summary"* ]]
    [[ "$head" == *"checkpoint.sh budget"* ]]
    # before the handover body, so a long handover cannot push it out
    local note_at where_at
    note_at=$(printf '%s' "$ctx" | grep -n 'Budget (T-5348)' | head -1 | cut -d: -f1)
    where_at=$(printf '%s' "$ctx" | grep -n '^## Where We Are' | head -1 | cut -d: -f1)
    [ -n "$note_at" ] && [ -n "$where_at" ] && [ "$note_at" -lt "$where_at" ]
}

@test "compact: budget note is within the visible first 2000 bytes" {
    ctx=$(context_for compact)
    assert_note_visible "$ctx"
}

@test "startup (auto-restart): budget note is within the visible first 2000 bytes" {
    ctx=$(context_for startup)
    assert_note_visible "$ctx"
}

@test "resume: budget note is within the visible first 2000 bytes" {
    ctx=$(context_for resume)
    assert_note_visible "$ctx"
}
