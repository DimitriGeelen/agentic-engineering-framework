#!/usr/bin/env bats
# T-2286 (OBS-057): demo-target structural guard for `fw work-on`.
#
# Surfaces under test:
#   - bin/fw `work-on)` resume path — gates started-work transition when
#     frontmatter contains `demo_target: true`. Bypasses: --i-am-demo-orchestrator
#     flag or FW_I_AM_DEMO_ORCHESTRATOR=1 env. Both log Tier-2 entry to
#     .context/working/.gate-bypass-log.yaml (category: demo-target-bypass).
#   - .tasks/templates/default.md — documents the optional `demo_target:` field.
#
# AC mapping (per .tasks/active/T-2286-*.md):
#   refuses bare resume on demo_target: true        — t1
#   block message names BOTH bypass mechanisms      — t2
#   --i-am-demo-orchestrator flag bypasses + logs   — t3
#   FW_I_AM_DEMO_ORCHESTRATOR=1 env bypasses + logs — t4
#   non-demo task work-on unaffected (regression)   — t5
#   default.md documents `demo_target:` field       — t6
#   bypass-log entry shape per mechanism            — t7

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2286-XXXXXX)"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.context/working"
    export FW_BIN="$FRAMEWORK_ROOT/bin/fw"
    # Demo-target fixture
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9999-fake-demo-target.md" <<EOF
---
id: T-9999
name: fake demo target
status: captured
workflow_type: build
owner: agent
horizon: now
demo_target: true
created: 2026-06-09
last_update: 2026-06-09
---
# T-9999

## Context
test
EOF
    # Non-demo fixture (regression control)
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9998-non-demo.md" <<EOF
---
id: T-9998
name: non-demo regression
status: captured
workflow_type: build
owner: agent
horizon: now
created: 2026-06-09
last_update: 2026-06-09
---
# T-9998

## Context
test
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "t1: bare resume on demo_target: true task is REFUSED (exit 1)" {
    cd "$TEST_TEMP_DIR"
    PROJECT_ROOT="$TEST_TEMP_DIR" run "$FW_BIN" work-on T-9999
    [ "$status" -eq 1 ]
    [[ "$output" == *"work-on refused"* ]]
    [[ "$output" == *"demo-target task"* ]]
    # Frontmatter must remain captured — block must come BEFORE update-task.sh
    run grep -E "^status:" "$TEST_TEMP_DIR/.tasks/active/T-9999-fake-demo-target.md"
    [[ "$output" == *"captured"* ]]
}

@test "t2: block message names BOTH bypass mechanisms verbatim (L-399 parity)" {
    cd "$TEST_TEMP_DIR"
    PROJECT_ROOT="$TEST_TEMP_DIR" run "$FW_BIN" work-on T-9999
    [ "$status" -eq 1 ]
    [[ "$output" == *"--i-am-demo-orchestrator"* ]]
    [[ "$output" == *"FW_I_AM_DEMO_ORCHESTRATOR=1"* ]]
}

@test "t3: --i-am-demo-orchestrator flag bypasses gate and resumes task" {
    cd "$TEST_TEMP_DIR"
    PROJECT_ROOT="$TEST_TEMP_DIR" run "$FW_BIN" work-on T-9999 --i-am-demo-orchestrator
    [ "$status" -eq 0 ]
    [[ "$output" == *"Resuming T-9999"* ]] || [[ "$output" == *"Ready to work on T-9999"* ]]
    run grep -E "^status:" "$TEST_TEMP_DIR/.tasks/active/T-9999-fake-demo-target.md"
    [[ "$output" == *"started-work"* ]]
}

@test "t4: FW_I_AM_DEMO_ORCHESTRATOR=1 env-var bypasses gate and resumes task" {
    cd "$TEST_TEMP_DIR"
    PROJECT_ROOT="$TEST_TEMP_DIR" FW_I_AM_DEMO_ORCHESTRATOR=1 run "$FW_BIN" work-on T-9999
    [ "$status" -eq 0 ]
    run grep -E "^status:" "$TEST_TEMP_DIR/.tasks/active/T-9999-fake-demo-target.md"
    [[ "$output" == *"started-work"* ]]
}

@test "t5: non-demo task (no demo_target field) work-on is unaffected" {
    cd "$TEST_TEMP_DIR"
    PROJECT_ROOT="$TEST_TEMP_DIR" run "$FW_BIN" work-on T-9998
    [ "$status" -eq 0 ]
    run grep -E "^status:" "$TEST_TEMP_DIR/.tasks/active/T-9998-non-demo.md"
    [[ "$output" == *"started-work"* ]]
}

@test "t6: default task template documents the optional demo_target: field" {
    run grep -E "^# demo_target:" "$FRAMEWORK_ROOT/.tasks/templates/default.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"demo_target"* ]]
    # Field comment must point at the bypass mechanisms — agents searching the
    # template should find both names in-place.
    run grep -E "i-am-demo-orchestrator|FW_I_AM_DEMO_ORCHESTRATOR" "$FRAMEWORK_ROOT/.tasks/templates/default.md"
    [ "$status" -eq 0 ]
}

@test "t7: bypass-log entry shape — category, mechanism per bypass path" {
    cd "$TEST_TEMP_DIR"
    PROJECT_ROOT="$TEST_TEMP_DIR" "$FW_BIN" work-on T-9999 --i-am-demo-orchestrator > /dev/null 2>&1
    # Reset for env-bypass leg
    sed -i 's/status: started-work/status: captured/' "$TEST_TEMP_DIR/.tasks/active/T-9999-fake-demo-target.md"
    PROJECT_ROOT="$TEST_TEMP_DIR" FW_I_AM_DEMO_ORCHESTRATOR=1 "$FW_BIN" work-on T-9999 > /dev/null 2>&1

    log_file="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    [ -f "$log_file" ]
    run grep "category: 'demo-target-bypass'" "$log_file"
    [ "$status" -eq 0 ]
    run grep "mechanism: 'flag:--i-am-demo-orchestrator'" "$log_file"
    [ "$status" -eq 0 ]
    run grep "mechanism: 'env:FW_I_AM_DEMO_ORCHESTRATOR'" "$log_file"
    [ "$status" -eq 0 ]
}
