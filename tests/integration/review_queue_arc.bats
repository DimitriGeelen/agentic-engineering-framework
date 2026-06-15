#!/usr/bin/env bats
# T-2405: `fw review-queue --arc <id>` filter.
#
# Pins:
#   - --arc arc-NNN form matches tasks whose arc_id: resolves to that id
#   - --arc <slug> form matches the same set as --arc arc-NNN
#   - legacy `tags: [arc:<slug>, ...]` form is matched (T-1849 back-compat)
#   - unknown arc id → ERROR to stderr + exit 1
#   - no flag → corpus-wide baseline preserved (regression guard)

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    unset _FW_PATHS_LOADED
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/arcs"
    touch "$PROJECT_ROOT/.framework.yaml"

    # Two arcs to disambiguate.
    cat > "$PROJECT_ROOT/.context/arcs/orchestrator-rethink.yaml" <<EOF
id: arc-003
slug: orchestrator-rethink
name: Orchestrator routing rethink
status: in-progress
EOF
    cat > "$PROJECT_ROOT/.context/arcs/embeddings-strategy.yaml" <<EOF
id: arc-002
slug: embeddings-strategy
name: Embeddings strategy
status: in-progress
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_write_partial_complete() {
    # Build a task with status=work-completed + unchecked Human AC + a
    # ## Recommendation: GO block, so review-queue surfaces it.
    local tid="$1" arc_id_field="$2" extra_tags="$3"
    cat > "$PROJECT_ROOT/.tasks/active/${tid}-t.md" <<EOF
---
id: ${tid}
name: "test task"
status: work-completed
workflow_type: build
owner: human
horizon: now
${arc_id_field}
tags: [${extra_tags}]
created: 2026-04-11T22:00:00Z
last_update: 2026-04-11T22:00:00Z
---

# ${tid}: test task

## Acceptance Criteria

### Agent
- [x] done

### Human
- [ ] [RUBBER-STAMP] verify

## Recommendation

**Recommendation:** GO

**Rationale:** done.

**Evidence:** none.
EOF
}

@test "--arc arc-NNN form matches tasks tagged with that arc" {
    _write_partial_complete "T-9001" "arc_id: orchestrator-rethink" ""
    _write_partial_complete "T-9002" "arc_id: embeddings-strategy" ""
    run "$FW" review-queue --arc arc-003
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" != *"T-9002"* ]]
}

@test "--arc slug form matches the same set as --arc arc-NNN" {
    _write_partial_complete "T-9001" "arc_id: orchestrator-rethink" ""
    _write_partial_complete "T-9002" "arc_id: embeddings-strategy" ""
    run "$FW" review-queue --arc orchestrator-rethink
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" != *"T-9002"* ]]
}

@test "--arc matches arc_id: in arc-NNN form (not just slug)" {
    _write_partial_complete "T-9003" "arc_id: arc-003" ""
    run "$FW" review-queue --arc arc-003
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9003"* ]]
}

@test "--arc matches legacy tags: [arc:<slug>] form (T-1849 back-compat)" {
    _write_partial_complete "T-9004" "" "arc:orchestrator-rethink"
    _write_partial_complete "T-9005" "" "arc:embeddings-strategy"
    run "$FW" review-queue --arc arc-003
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9004"* ]]
    [[ "$output" != *"T-9005"* ]]
}

@test "--arc unknown-id errors to stderr + exits 1" {
    _write_partial_complete "T-9001" "arc_id: orchestrator-rethink" ""
    run "$FW" review-queue --arc not-a-real-arc
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: --arc not-a-real-arc"* ]]
}

@test "no flag → corpus-wide baseline (regression guard)" {
    _write_partial_complete "T-9001" "arc_id: orchestrator-rethink" ""
    _write_partial_complete "T-9002" "arc_id: embeddings-strategy" ""
    run "$FW" review-queue
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" == *"T-9002"* ]]
}

@test "--help documents --arc flag" {
    run "$FW" review-queue --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--arc"* ]]
    [[ "$output" == *"arc-NNN"* ]]
    [[ "$output" == *"slug"* ]]
}
