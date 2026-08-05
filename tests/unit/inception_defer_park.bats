#!/usr/bin/env bats
# T-1865 — DEFER inception decisions park the task instead of leaving it
# stuck at status=started-work / horizon=now. Two surfaces:
#   1. do_inception_sweep recovers existing DEFER limbo tasks
#   2. (Decide-defer path is interactive / Tier-0-gated; covered indirectly
#      by sweep + manual smoke against this repo's 6 limbo tasks.)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.context/working"
    echo "framework_path: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    # Synthetic limbo task: inception + started-work + DEFER recorded + ACs ticked.
    cat > "$PROJECT_ROOT/.tasks/active/T-9900-defer-limbo.md" <<'EOF'
---
id: T-9900
name: "limbo defer"
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-01T00:00:00Z
last_update: 2026-05-01T00:00:00Z
date_finished: null
---

# T-9900: limbo defer

## Acceptance Criteria

### Agent
- [x] explored

### Human
- [x] reviewed

## Recommendation

**Recommendation:** DEFER — no demand yet.

## Decision

**Decision**: DEFER
**Rationale**: not now
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "T-1865: sweep --dry-run lists DEFER limbo as eligible with park marker" {
    run "$FRAMEWORK_ROOT/bin/fw" inception sweep --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9900"* ]]
    [[ "$output" == *"decision=DEFER"* ]]
    [[ "$output" == *"T-1865 park"* ]]
    [[ "$output" == *"eligible=1"* ]]
}

@test "T-1865: sweep applies park transition — horizon→later, status→captured" {
    run "$FRAMEWORK_ROOT/bin/fw" inception sweep
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9900"* ]]
    [[ "$output" == *"parked"* ]]
    # File stayed in active/ (parked, not moved to completed)
    [ -f "$PROJECT_ROOT/.tasks/active/T-9900-defer-limbo.md" ]
    [ ! -f "$PROJECT_ROOT/.tasks/completed/T-9900-defer-limbo.md" ]
    # Horizon now later
    out=$(grep "^horizon:" "$PROJECT_ROOT/.tasks/active/T-9900-defer-limbo.md")
    [[ "$out" == *"later"* ]]
    # Status auto-demoted to captured via T-1068 invariant
    out=$(grep "^status:" "$PROJECT_ROOT/.tasks/active/T-9900-defer-limbo.md")
    [[ "$out" == *"captured"* ]]
}

@test "T-1865: sweep does NOT touch DEFER tasks already at horizon=later" {
    # Pre-park the task — sweep should still be safe (re-running sweep is idempotent).
    sed -i 's/^horizon: now/horizon: later/' "$PROJECT_ROOT/.tasks/active/T-9900-defer-limbo.md"
    sed -i 's/^status: started-work/status: captured/' "$PROJECT_ROOT/.tasks/active/T-9900-defer-limbo.md"
    run "$FRAMEWORK_ROOT/bin/fw" inception sweep --dry-run
    [ "$status" -eq 0 ]
    # status=captured no longer matches case selector → not eligible
    [[ "$output" == *"eligible=0"* ]]
}
