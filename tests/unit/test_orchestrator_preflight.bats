#!/usr/bin/env bats
# T-2340 (arc-011 M1 §6) — disjointness pre-flight gate.
#
# Pins `agents/orchestrator/orchestrator-graph.py::pre_flight_check` and
# `fw orchestrator pre-flight T-XXX` CLI verb:
#   - no in-flight dispatch → exit 0 (allowed)
#   - in-flight overlap → exit 1 + stderr names dispatch id + path
#   - in-flight non-overlap → exit 0
#   - history with only completed entries → exit 0
#   - task without write_set → exit 0 with note (conservative undecidable)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    TEST_REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$TEST_REPO/.tasks/active" "$TEST_REPO/.tasks/completed" \
             "$TEST_REPO/.context" "$TEST_REPO/docs/reports"
    cd "$TEST_REPO"
    export PROJECT_ROOT="$TEST_REPO"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_write_task() {
    # _write_task <id> <write-set-yaml>
    local id="$1" ws="$2"
    cat > ".tasks/active/${id}-test.md" <<EOF
---
id: $id
name: "$id"
description: "$id fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
$ws
---

# $id
EOF
}

@test "no in-flight dispatch → exit 0 (allowed)" {
    _write_task "T-PF-A" "write_set: [docs/A.md]"
    # No .context/dispatches.jsonl file at all
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator pre-flight T-PF-A
    [ "$status" -eq 0 ]
    [[ "$output" == *"allowed"* ]]
}

@test "in-flight overlap → exit 1 + stderr names dispatch id + path" {
    _write_task "T-PF-A" "write_set: [docs/SHARED.md]"
    _write_task "T-PF-B" "write_set: [docs/SHARED.md]"
    # T-PF-B is in-flight (outcome empty); checking T-PF-A
    cat > ".context/dispatches.jsonl" <<EOF
{"dispatch_id":"D-100","task_id":"T-PF-B","outcome":""}
EOF
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator pre-flight T-PF-A
    [ "$status" -eq 1 ]
    # stderr is captured into $output by bats run; check both id and path appear
    [[ "$output" == *"D-100"* ]]
    [[ "$output" == *"docs/SHARED.md"* ]]
}

@test "in-flight non-overlap → exit 0 (allowed)" {
    _write_task "T-PF-A" "write_set: [docs/A.md]"
    _write_task "T-PF-B" "write_set: [docs/B.md]"
    cat > ".context/dispatches.jsonl" <<EOF
{"dispatch_id":"D-200","task_id":"T-PF-B","outcome":""}
EOF
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator pre-flight T-PF-A
    [ "$status" -eq 0 ]
    [[ "$output" == *"allowed"* ]]
}

@test "history with only completed entries → exit 0" {
    _write_task "T-PF-A" "write_set: [docs/SHARED.md]"
    _write_task "T-PF-B" "write_set: [docs/SHARED.md]"
    # T-PF-B's dispatch has a non-empty outcome → not in-flight
    cat > ".context/dispatches.jsonl" <<EOF
{"dispatch_id":"D-300","task_id":"T-PF-B","outcome":"success"}
EOF
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator pre-flight T-PF-A
    [ "$status" -eq 0 ]
    [[ "$output" == *"allowed"* ]]
}

@test "task without write_set → exit 0 with note (conservative undecidable)" {
    _write_task "T-PF-NOWS" ""
    # No dispatches.jsonl
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator pre-flight T-PF-NOWS
    [ "$status" -eq 0 ]
    [[ "$output" == *"allowed"* ]]
    [[ "$output" == *"no write_set"* ]]
    [[ "$output" == *"undecidable"* ]]
}

@test "task not found → exit 2" {
    # No active task created
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator pre-flight T-NEVER-FILED
    [ "$status" -eq 2 ]
    [[ "$output" == *"not found"* ]]
}

@test "missing arg → exit 64 usage" {
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator pre-flight
    [ "$status" -eq 64 ]
    [[ "$output" == *"usage"* ]]
}
