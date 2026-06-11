#!/usr/bin/env bats
# T-2339 (arc-011 M1 §1) — orchestrator-graph dispatch decision.
#
# Pins `agents/orchestrator/orchestrator-graph.py` + `fw orchestrator next-dispatch`:
#   - 2 disjoint tasks → both parallel
#   - 2 overlapping tasks → 1 parallel 1 serial (later round)
#   - chain dependency (A→B→C) → A parallel, B+C serial
#   - empty active pool → exit 0 + empty output
#   - task without write_set → mode=serial (conservative undecidable handling)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    TEST_REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$TEST_REPO/.tasks/active" "$TEST_REPO/.tasks/completed" \
             "$TEST_REPO/docs/reports"
    cd "$TEST_REPO"
    export PROJECT_ROOT="$TEST_REPO"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_write_task() {
    # _write_task <id> <write-set-yaml> [related-tasks-yaml]
    local id="$1" ws="$2" rel="${3:-}"
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
$rel
---

# $id
EOF
}

@test "2 disjoint tasks → both parallel" {
    _write_task "T-PAR-A" "write_set: [docs/reports/T-PAR-A.md]"
    _write_task "T-PAR-B" "write_set: [docs/reports/T-PAR-B.md]"
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator next-dispatch
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-PAR-A"$'\t'"parallel"* ]]
    [[ "$output" == *"T-PAR-B"$'\t'"parallel"* ]]
}

@test "2 overlapping tasks → first parallel-of-1 (serial), second serial" {
    _write_task "T-COL-A" "write_set: [docs/SHARED.md]"
    _write_task "T-COL-B" "write_set: [docs/SHARED.md]"
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator next-dispatch
    [ "$status" -eq 0 ]
    # Both are emitted, but in separate rounds — each as serial (round-size 1)
    [[ "$output" == *"T-COL-A"$'\t'"serial"* ]]
    [[ "$output" == *"T-COL-B"$'\t'"serial"* ]]
}

@test "chain dependency A → B → C — A parallel/alone, then B, then C" {
    # T-CHAIN-A has no deps; T-CHAIN-B related_tasks: [T-CHAIN-A]; T-CHAIN-C related_tasks: [T-CHAIN-B]
    _write_task "T-CHAIN-A" "write_set: [docs/A.md]" ""
    _write_task "T-CHAIN-B" "write_set: [docs/B.md]" "related_tasks: [T-CHAIN-A]"
    _write_task "T-CHAIN-C" "write_set: [docs/C.md]" "related_tasks: [T-CHAIN-B]"
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator next-dispatch
    [ "$status" -eq 0 ]
    # Each round has size 1 (chain) → all serial
    [[ "$output" == *"T-CHAIN-A"$'\t'"serial"* ]]
    [[ "$output" == *"T-CHAIN-B"$'\t'"serial"* ]]
    [[ "$output" == *"T-CHAIN-C"$'\t'"serial"* ]]
    # Topological order: A before B before C in output
    a_line=$(echo "$output" | grep -n "T-CHAIN-A" | head -1 | cut -d: -f1)
    b_line=$(echo "$output" | grep -n "T-CHAIN-B" | head -1 | cut -d: -f1)
    c_line=$(echo "$output" | grep -n "T-CHAIN-C" | head -1 | cut -d: -f1)
    [ "$a_line" -lt "$b_line" ]
    [ "$b_line" -lt "$c_line" ]
}

@test "empty active pool — exit 0, no output" {
    # No tasks created
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator next-dispatch
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "task without write_set — undecidable pair → mode=serial" {
    _write_task "T-NO-A" ""
    _write_task "T-NO-B" "write_set: [docs/B.md]"
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator next-dispatch
    [ "$status" -eq 0 ]
    # Undecidable pair → each task gets its own round → serial
    [[ "$output" == *"T-NO-A"$'\t'"serial"* ]]
    [[ "$output" == *"T-NO-B"$'\t'"serial"* ]]
}

@test "3 disjoint tasks → all parallel in one round" {
    _write_task "T-MULTI-A" "write_set: [a.md]"
    _write_task "T-MULTI-B" "write_set: [b.md]"
    _write_task "T-MULTI-C" "write_set: [c.md]"
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator next-dispatch
    [ "$status" -eq 0 ]
    parallel_count=$(echo "$output" | grep -c "parallel" || true)
    [ "$parallel_count" -eq 3 ]
}
