#!/usr/bin/env bats
# T-1573 / F8 — Audit must surface .gate-bypass-log.yaml. Auth-flag bypasses
# (--skip-sovereignty, --skip-acceptance-criteria, etc.) are logged by
# update-task.sh:32-42 but were "an audit artefact without auditor" until
# this surface was added (T-1565 audit F8).

load ../test_helper

AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/audits"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "gate-bypass log absent: PASS clean state" {
    run "$AUDIT" --section enforcement
    [ "$status" -le 1 ]  # 0 or 1 (warnings ok, no fails)
    [[ "$output" == *"Gate-bypass log: clean"* ]]
}

@test "gate-bypass log with low recent count: PASS" {
    log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    cat > "$log" <<'EOF'
- timestamp: '2026-04-25T10:00:00Z'
  task: 'T-9001'
  flag: '--skip-sovereignty'
  caller: 'check_human_sovereignty'
  reason: 'test'
- timestamp: '2026-04-26T10:00:00Z'
  task: 'T-9002'
  flag: '--skip-rca'
  caller: 'check_rca_for_bugfix'
  reason: 'test'
EOF
    run "$AUDIT" --section enforcement
    [ "$status" -le 1 ]
    [[ "$output" == *"Gate-bypass log:"* ]]
    [[ "$output" == *"PASS"* ]]
}

@test "gate-bypass log with >10 entries in 7d: WARN" {
    log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    : > "$log"
    today=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    for i in $(seq 1 12); do
        cat >> "$log" <<EOF
- timestamp: '$today'
  task: 'T-90$(printf "%02d" $i)'
  flag: '--skip-sovereignty'
  caller: 'check_human_sovereignty'
  reason: 'test'
EOF
    done
    run "$AUDIT" --section enforcement
    # Audit returns 1 when warnings exist, which is allowed
    [[ "$output" == *"Gate-bypass log:"* ]]
    [[ "$output" == *"bypasses in last 7 days"* ]]
    [[ "$output" == *"WARN"* ]]
}

@test "gate-bypass log with old entries only: not in 7d count" {
    log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    : > "$log"
    # Use clearly-old timestamps
    for i in $(seq 1 15); do
        cat >> "$log" <<EOF
- timestamp: '2025-01-01T00:00:00Z'
  task: 'T-91$(printf "%02d" $i)'
  flag: '--skip-rca'
  caller: 'check_rca_for_bugfix'
  reason: 'test'
EOF
    done
    run "$AUDIT" --section enforcement
    # 15 total but 0 in last 7d → PASS (low recent count)
    [[ "$output" == *"Gate-bypass log: 0 in last 7 days"* ]]
    [[ "$output" == *"15 total"* ]]
}
