#!/usr/bin/env bats
# Unit tests for check-inception-schema hook (T-2188).
#
# Inception tasks must declare target_blast_radius (int 0..9) and voi_score
# (float 0..1). The hook blocks Write/Edit on inception task files missing
# these fields. Bypass: FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1 (logged Tier-2).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    unset FW_ALLOW_INCEPTION_SCHEMA_DRIFT
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-inception-schema.py"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    unset FW_ALLOW_INCEPTION_SCHEMA_DRIFT
}

_make_task() {
    local id="$1" wf="$2" tbr="$3" voi="$4"
    local path="$TEST_TEMP_DIR/.tasks/active/${id}-x.md"
    {
        echo "---"
        echo "id: $id"
        echo "workflow_type: $wf"
        [ -n "$tbr" ] && echo "target_blast_radius: $tbr"
        [ -n "$voi" ] && echo "voi_score: $voi"
        echo "---"
        echo "body"
    } > "$path"
    echo "$path"
}

_call_hook() {
    local file="$1"
    echo "{\"tool_input\":{\"file_path\":\"$file\"}}" | python3 "$HOOK"
}

@test "valid inception (both fields in range) passes" {
    file=$(_make_task T-9000 inception 3 0.5)
    run _call_hook "$file"
    [ "$status" -eq 0 ]
}

@test "build task is exempt regardless of fields" {
    file=$(_make_task T-9001 build "" "")
    run _call_hook "$file"
    [ "$status" -eq 0 ]
}

@test "missing target_blast_radius blocks" {
    file=$(_make_task T-9002 inception "" 0.5)
    run _call_hook "$file"
    [ "$status" -eq 2 ]
    [[ "$output" == *"target_blast_radius missing"* ]]
}

@test "missing voi_score blocks" {
    file=$(_make_task T-9003 inception 3 "")
    run _call_hook "$file"
    [ "$status" -eq 2 ]
    [[ "$output" == *"voi_score missing"* ]]
}

@test "target_blast_radius out of range (10) blocks" {
    file=$(_make_task T-9004 inception 10 0.5)
    run _call_hook "$file"
    [ "$status" -eq 2 ]
    [[ "$output" == *"out of range"* ]]
}

@test "voi_score out of range (1.5) blocks" {
    file=$(_make_task T-9005 inception 3 1.5)
    run _call_hook "$file"
    [ "$status" -eq 2 ]
    [[ "$output" == *"out of range"* ]]
}

@test "non-task-file path is ignored" {
    run bash -c "echo '{\"tool_input\":{\"file_path\":\"$TEST_TEMP_DIR/random.txt\"}}' | python3 $HOOK"
    [ "$status" -eq 0 ]
}

@test "FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1 bypasses and logs" {
    file=$(_make_task T-9006 inception "" "")
    FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1 run _call_hook "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_ALLOW_INCEPTION_SCHEMA_DRIFT"* ]] || [[ -s "$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml" ]]
    # Log file should contain the bypass entry
    [ -f "$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml" ]
    grep -q "check-inception-schema" "$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    grep -q "FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1" "$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
}

@test "edge: target_blast_radius=0 (docs-only) passes" {
    file=$(_make_task T-9007 inception 0 0.0)
    run _call_hook "$file"
    [ "$status" -eq 0 ]
}

@test "edge: target_blast_radius=9 and voi_score=1.0 (max) passes" {
    file=$(_make_task T-9008 inception 9 1.0)
    run _call_hook "$file"
    [ "$status" -eq 0 ]
}
