#!/usr/bin/env bats
# T-2341 (arc-011 M1 §4) — single-host parallel demo integration test.
#
# Pins `agents/dispatch/single-host-parallel-demo.sh`:
#   - disjoint write_sets → demo exits 0 + assertions pass
#   - output files written by both workers
#   - overlap window observable in dispatches.jsonl
#   - clean .tasks/ tree (no merge conflict markers)
#   - overlap-detection is NOT vacuous: when fixtures share a write_set path,
#     the orchestrator-graph + pre-flight gate refuse the pair → demo exits 3
#
# Marked integration (not unit) because it spawns real subprocesses.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    SANDBOX="$TEST_TEMP_DIR/sandbox"
    mkdir -p "$SANDBOX"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "demo exits 0 with disjoint write_set fixtures (happy path)" {
    run bash "$FRAMEWORK_ROOT/agents/dispatch/single-host-parallel-demo.sh" \
        --sandbox "$SANDBOX"
    [ "$status" -eq 0 ]
    [[ "$output" == *"headline_mechanic FIRED"* ]]
    [[ "$output" == *"overlap window observed"* ]]
    [[ "$output" == *".tasks/ clean"* ]]
    [[ "$output" == *"output files exist"* ]]
}

@test "demo creates expected output files in sandbox" {
    run bash "$FRAMEWORK_ROOT/agents/dispatch/single-host-parallel-demo.sh" \
        --sandbox "$SANDBOX"
    [ "$status" -eq 0 ]
    [ -f "$SANDBOX/docs/reports/_demo/A.md" ]
    [ -f "$SANDBOX/docs/reports/_demo/B.md" ]
}

@test "dispatches.jsonl shows overlapping in-flight window" {
    run bash "$FRAMEWORK_ROOT/agents/dispatch/single-host-parallel-demo.sh" \
        --sandbox "$SANDBOX"
    [ "$status" -eq 0 ]
    # The jsonl must contain BOTH a start row (outcome="") for T-DEMO-A and
    # T-DEMO-B before either's completion row.
    [ -f "$SANDBOX/.context/dispatches.jsonl" ]
    grep -q '"task_id":"T-DEMO-A","outcome":""' "$SANDBOX/.context/dispatches.jsonl"
    grep -q '"task_id":"T-DEMO-B","outcome":""' "$SANDBOX/.context/dispatches.jsonl"
    grep -q '"task_id":"T-DEMO-A","outcome":"success"' "$SANDBOX/.context/dispatches.jsonl"
    grep -q '"task_id":"T-DEMO-B","outcome":"success"' "$SANDBOX/.context/dispatches.jsonl"
}

@test ".tasks/ stays clean — no merge conflict markers" {
    run bash "$FRAMEWORK_ROOT/agents/dispatch/single-host-parallel-demo.sh" \
        --sandbox "$SANDBOX"
    [ "$status" -eq 0 ]
    # Scan task fixtures for merge-conflict markers
    ! grep -rE '^<<<<<<<|^=======|^>>>>>>>' "$SANDBOX/.tasks/" 2>/dev/null
}

@test "overlap-detection NOT vacuous: overlapping fixtures refused upstream" {
    # Pre-create the sandbox with two fixtures that SHARE a write_set path.
    # The demo's own fixture creator will overwrite them — so we test the
    # upstream guards (orchestrator-graph + pre-flight) directly on a
    # hand-built overlap pair, mirroring what the demo would refuse if its
    # caller passed bad fixtures.
    mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context"
    cat > "$SANDBOX/.tasks/active/T-OVL-A-test.md" <<'EOF'
---
id: T-OVL-A
name: "T-OVL-A overlap"
description: "shared write_set fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
write_set: [docs/SHARED.md]
---

# T-OVL-A
EOF
    cat > "$SANDBOX/.tasks/active/T-OVL-B-test.md" <<'EOF'
---
id: T-OVL-B
name: "T-OVL-B overlap"
description: "shared write_set fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
write_set: [docs/SHARED.md]
---

# T-OVL-B
EOF
    export PROJECT_ROOT="$SANDBOX"
    # Orchestrator-graph: should serialise the pair (each emitted as `serial`,
    # NOT both `parallel`) — proving the disjoint check feeds the dispatch decision
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator next-dispatch
    [ "$status" -eq 0 ]
    # Neither should appear as `parallel` mode
    [[ "$output" != *"T-OVL-A"$'\t'"parallel"* ]]
    [[ "$output" != *"T-OVL-B"$'\t'"parallel"* ]]
    [[ "$output" == *"T-OVL-A"$'\t'"serial"* ]]
    [[ "$output" == *"T-OVL-B"$'\t'"serial"* ]]
}

@test "pre-flight refuses second worker when first is in-flight on same write_set" {
    # Simulate T-OVL-A already dispatched (in-flight) and test pre-flight on T-OVL-B
    mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context"
    cat > "$SANDBOX/.tasks/active/T-OVL-A-test.md" <<'EOF'
---
id: T-OVL-A
name: "in-flight worker"
description: "in-flight worker"
status: started-work
workflow_type: build
owner: agent
horizon: now
write_set: [docs/SHARED.md]
---
EOF
    cat > "$SANDBOX/.tasks/active/T-OVL-B-test.md" <<'EOF'
---
id: T-OVL-B
name: "candidate worker"
description: "candidate"
status: started-work
workflow_type: build
owner: agent
horizon: now
write_set: [docs/SHARED.md]
---
EOF
    cat > "$SANDBOX/.context/dispatches.jsonl" <<'EOF'
{"dispatch_id":"D-INFLIGHT","task_id":"T-OVL-A","outcome":""}
EOF
    export PROJECT_ROOT="$SANDBOX"
    run "$FRAMEWORK_ROOT/bin/fw" orchestrator pre-flight T-OVL-B
    [ "$status" -eq 1 ]
    [[ "$output" == *"D-INFLIGHT"* ]]
    [[ "$output" == *"docs/SHARED.md"* ]]
}
