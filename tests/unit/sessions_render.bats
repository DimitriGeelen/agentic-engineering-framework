#!/usr/bin/env bats
# T-2417: Generic session renderer — verifies project-grouped tree rendering
# from canonical JSONL per agents/sessions/SCHEMA.md.
#
# The renderer is agent-neutral: it never reads CC-specific fields; it consumes
# only canonical JSONL. These tests pipe canned JSONL (independent of any
# provider) to render.py and assert layout / ordering / formatting.
#
# AC mapping:
#   t1  empty input → "(no sessions)"
#   t2  malformed JSONL line → skipped with stderr warning, valid lines still rendered
#   t3  state subgroup ordering: needs-input → working → completed
#   t4  project ordering: real projects alphabetical, then (loose) last
#   t5  within-state ordering: most-recent first (smallest age_seconds)
#   t6  age formatting: 30s→"< 1m", 600s→"10m", 7200s→"2h", 172800s→"2d", 1209600s→"2w"
#   t7  glyph selection: ✻ for needs-input/working, ∙ for completed
#   t8  description column tightens when no descriptions present

load ../test_helper

RENDER="$FRAMEWORK_ROOT/agents/sessions/render.py"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "t1: empty input → (no sessions)" {
    run bash -c "echo '' | python3 '$RENDER'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"(no sessions)"* ]]
}

@test "t2: malformed JSONL line skipped with stderr warning" {
    input='{"provider":"x","project":"P","name":"good","state":"working","age_seconds":60,"session_id":"s1"}
not-json-at-all
{"provider":"x","project":"P","name":"good2","state":"completed","age_seconds":120,"session_id":"s2"}'
    run bash -c "printf '%s\n' '$input' | python3 '$RENDER' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping malformed JSONL line"* ]]
    [[ "$output" == *"good"* ]]
    [[ "$output" == *"good2"* ]]
}

@test "t3: state subgroup order — needs-input → working → completed" {
    input='{"provider":"x","project":"A","name":"c","state":"completed","age_seconds":1,"session_id":"s1"}
{"provider":"x","project":"A","name":"w","state":"working","age_seconds":2,"session_id":"s2"}
{"provider":"x","project":"A","name":"n","state":"needs-input","age_seconds":3,"session_id":"s3"}'
    run bash -c "printf '%s\n' '$input' | python3 '$RENDER'"
    [ "$status" -eq 0 ]
    needs_line=$(echo "$output" | grep -n "Needs input" | head -1 | cut -d: -f1)
    working_line=$(echo "$output" | grep -n "Working" | head -1 | cut -d: -f1)
    completed_line=$(echo "$output" | grep -n "Completed" | head -1 | cut -d: -f1)
    [ "$needs_line" -lt "$working_line" ]
    [ "$working_line" -lt "$completed_line" ]
}

@test "t4: project order — real alphabetical, (loose) last" {
    input='{"provider":"x","project":"(loose)","name":"l","state":"working","age_seconds":1,"session_id":"s1"}
{"provider":"x","project":"zeta","name":"z","state":"working","age_seconds":2,"session_id":"s2"}
{"provider":"x","project":"alpha","name":"a","state":"working","age_seconds":3,"session_id":"s3"}'
    run bash -c "printf '%s\n' '$input' | python3 '$RENDER'"
    [ "$status" -eq 0 ]
    alpha_line=$(echo "$output" | grep -n "^// alpha" | head -1 | cut -d: -f1)
    zeta_line=$(echo "$output" | grep -n "^// zeta" | head -1 | cut -d: -f1)
    loose_line=$(echo "$output" | grep -n "^// (loose)" | head -1 | cut -d: -f1)
    [ "$alpha_line" -lt "$zeta_line" ]
    [ "$zeta_line" -lt "$loose_line" ]
}

@test "t5: within-state, most-recent first (smallest age_seconds)" {
    input='{"provider":"x","project":"A","name":"old","state":"working","age_seconds":10000,"session_id":"s1"}
{"provider":"x","project":"A","name":"new","state":"working","age_seconds":60,"session_id":"s2"}
{"provider":"x","project":"A","name":"mid","state":"working","age_seconds":1000,"session_id":"s3"}'
    run bash -c "printf '%s\n' '$input' | python3 '$RENDER'"
    [ "$status" -eq 0 ]
    new_line=$(echo "$output" | grep -n " new " | head -1 | cut -d: -f1)
    mid_line=$(echo "$output" | grep -n " mid " | head -1 | cut -d: -f1)
    old_line=$(echo "$output" | grep -n " old " | head -1 | cut -d: -f1)
    [ "$new_line" -lt "$mid_line" ]
    [ "$mid_line" -lt "$old_line" ]
}

@test "t6: age formatting" {
    input='{"provider":"x","project":"A","name":"under1m","state":"working","age_seconds":30,"session_id":"s1"}
{"provider":"x","project":"A","name":"under1h","state":"working","age_seconds":600,"session_id":"s2"}
{"provider":"x","project":"A","name":"under1d","state":"working","age_seconds":7200,"session_id":"s3"}
{"provider":"x","project":"A","name":"under1w","state":"working","age_seconds":172800,"session_id":"s4"}
{"provider":"x","project":"A","name":"weeks","state":"working","age_seconds":1209600,"session_id":"s5"}'
    run bash -c "printf '%s\n' '$input' | python3 '$RENDER'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"< 1m"* ]]
    [[ "$output" == *"10m"* ]]
    [[ "$output" == *"2h"* ]]
    [[ "$output" == *"2d"* ]]
    [[ "$output" == *"2w"* ]]
}

@test "t7: glyph selection — ✻ for active, ∙ for completed" {
    input='{"provider":"x","project":"A","name":"workitem","state":"working","age_seconds":60,"session_id":"s1"}
{"provider":"x","project":"A","name":"doneitem","state":"completed","age_seconds":120,"session_id":"s2"}'
    run bash -c "printf '%s\n' '$input' | python3 '$RENDER'"
    [ "$status" -eq 0 ]
    # Active rows carry the ✻ glyph; completed rows carry ∙
    workitem_line=$(echo "$output" | grep "workitem")
    doneitem_line=$(echo "$output" | grep "doneitem")
    [[ "$workitem_line" == *"✻"* ]]
    [[ "$doneitem_line" == *"∙"* ]]
}

@test "t8: no description → no padding gap before age" {
    # Description-less row has age right after name; description row has a
    # middle column. We verify by line length — without desc, the rendered
    # line is shorter than with desc.
    no_desc='{"provider":"x","project":"A","name":"plain","state":"working","age_seconds":60,"session_id":"s1"}'
    with_desc='{"provider":"x","project":"A","name":"plain","state":"working","age_seconds":60,"session_id":"s1","description":"some-desc"}'
    no_desc_len=$(printf '%s\n' "$no_desc" | python3 "$RENDER" | grep "plain" | awk '{print length}')
    with_desc_len=$(printf '%s\n' "$with_desc" | python3 "$RENDER" | grep "plain" | awk '{print length}')
    [ "$no_desc_len" -lt "$with_desc_len" ]
}
