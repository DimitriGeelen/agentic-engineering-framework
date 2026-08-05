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
    guard_project_root
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

@test "T-1862: many --switch-focus drift overrides + few safety bypasses → PASS not WARN" {
    log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    : > "$log"
    today=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # 20 drift overrides (operational noise) + 2 safety bypasses (below threshold of 3)
    for i in $(seq 1 20); do
        cat >> "$log" <<EOF
- timestamp: '$today'
  task: 'T-92$(printf "%02d" $i)'
  flag: '--switch-focus'
  caller: 'check-active-task focus-drift'
EOF
    done
    for i in $(seq 1 2); do
        cat >> "$log" <<EOF
- timestamp: '$today'
  task: 'T-94$(printf "%02d" $i)'
  flag: '--skip-rca'
  caller: 'check_rca_for_bugfix'
  reason: 'test'
EOF
    done
    run "$AUDIT" --section enforcement
    [ "$status" -le 1 ]
    # PASS — safety count (2) is below threshold of 3
    [[ "$output" == *"Gate-bypass log: 2 safety + 20 drift"* ]]
    [[ "$output" == *"PASS"* ]]
}

@test "T-1862: 4+ safety bypasses → WARN even with few drift overrides" {
    log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    : > "$log"
    today=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # 4 safety bypasses (above threshold) + 1 drift override
    for i in $(seq 1 4); do
        cat >> "$log" <<EOF
- timestamp: '$today'
  task: 'T-95$(printf "%02d" $i)'
  flag: '--skip-sovereignty'
  caller: 'check_human_sovereignty'
  reason: 'test'
EOF
    done
    cat >> "$log" <<EOF
- timestamp: '$today'
  task: 'T-9600'
  flag: '--switch-focus'
  caller: 'check-active-task focus-drift'
EOF
    run "$AUDIT" --section enforcement
    [[ "$output" == *"4 safety bypasses"* ]]
    [[ "$output" == *"WARN"* ]]
}

@test "T-1861: log_gate_bypass escapes embedded single quotes in REASON (YAML parses)" {
    # Source the function. update-task.sh has top-level side effects when sourced
    # directly, so extract just log_gate_bypass via a subshell.
    HOOK_SRC="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    [ -f "$HOOK_SRC" ] || skip "update-task.sh not found"

    log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    # Drive log_gate_bypass with a REASON containing single quotes — the exact
    # corruption pattern surfaced on 2026-05-15 (.gate-bypass-log.yaml:390).
    TASK_ID="T-9999" REASON="bin/fw doctor reports 'OK Hook exercise from /tmp: 14 hook(s) resolve from foreign CWD'." PROJECT_ROOT="$PROJECT_ROOT" \
        bash -c "source '$HOOK_SRC' --source-only 2>/dev/null; log_gate_bypass --canary 'canary-caller'" 2>/dev/null || true

    # Fallback if the script doesn't support --source-only: extract function via awk + eval
    if [ ! -s "$log" ]; then
        FN=$(awk '/^log_gate_bypass\(\)/,/^}/' "$HOOK_SRC")
        TASK_ID="T-9999" REASON="bin/fw doctor reports 'OK Hook exercise from /tmp: 14 hook(s) resolve from foreign CWD'." PROJECT_ROOT="$PROJECT_ROOT" \
            bash -c "$FN; log_gate_bypass --canary 'canary-caller'"
    fi

    # Log must parse as valid YAML
    python3 -c "import yaml,sys; data = yaml.safe_load(open('$log')); assert isinstance(data, list) and len(data) >= 1; assert any(e.get('task')=='T-9999' for e in data), data"
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
    # T-1862: output now reports per-class counts; both classes 0 in window.
    [[ "$output" == *"Gate-bypass log: 0 safety + 0 drift in last 7 days"* ]]
    [[ "$output" == *"15 total"* ]]
}
