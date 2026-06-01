#!/usr/bin/env bats
# T-2162 / CTL-030: completed/ stored-horizon drift detection
#
# arc-009 horizon-axis-hardening Slice 3.
# After T-2160 derives render-time `past` from _location, the stored
# `horizon:` field on completed/ files is behaviorally irrelevant. T-2161
# nulled the existing 1828-file pile. This rail catches future drift —
# every task that closes carries `horizon: now/next/later` from its
# active-state YAML until `bin/migrate-horizon-null-completed.sh` reruns.
#
# Empty/absent/null/~ are LEGITIMATE (117 pre-frontmatter-template-era
# files have no horizon field at all) — they must NOT trip this rail.

load ../test_helper

SCAN="$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py"

setup() {
    TMPREPO=$(mktemp -d)
    export TMPREPO
    mkdir -p "$TMPREPO/.tasks/completed" "$TMPREPO/.tasks/active" \
             "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
}

teardown() {
    [ -d "${TMPREPO:-}" ] && rm -rf "$TMPREPO"
}

# Helper: write a completed-task md file with the given horizon value.
# Pass empty string ("") for absent-field case; pass "null" for explicit null.
_write_task_with_horizon() {
    local id="$1" horizon="$2"
    if [ -n "$horizon" ]; then
        cat > "$TMPREPO/.tasks/completed/${id}-test.md" <<EOF
---
id: $id
name: "test task"
status: work-completed
workflow_type: build
owner: claude-code
horizon: $horizon
created: 2026-05-15T00:00:00Z
last_update: 2026-05-15T00:00:00Z
date_finished: 2026-05-15T00:00:00Z
---

# $id: test

## Acceptance Criteria

### Agent
- [x] Done
EOF
    else
        # absent-field variant (pre-frontmatter-template-era simulation)
        cat > "$TMPREPO/.tasks/completed/${id}-test.md" <<EOF
---
id: $id
name: "test task"
status: work-completed
workflow_type: build
owner: claude-code
created: 2026-05-15T00:00:00Z
last_update: 2026-05-15T00:00:00Z
date_finished: 2026-05-15T00:00:00Z
---

# $id: test
EOF
    fi
}

@test "CTL-030 fail: completed/ with horizon=now surfaces in horizon_drift" {
    _write_task_with_horizon "T-9100" "now"
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    drift_count=$(echo "$output" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('horizon_drift',[])))")
    [ "$drift_count" = "1" ]
    entry=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin)['horizon_drift'][0]; print(f\"{d['id']}|{d['horizon']}\")")
    [ "$entry" = "T-9100|now" ]
}

@test "CTL-030 fail: horizon=next and horizon=later also surface" {
    _write_task_with_horizon "T-9101" "next"
    _write_task_with_horizon "T-9102" "later"
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    drift_ids=$(echo "$output" | python3 -c "import sys,json; print(','.join(sorted(i['id'] for i in json.load(sys.stdin).get('horizon_drift',[]))))")
    [ "$drift_ids" = "T-9101,T-9102" ]
}

@test "CTL-030 pass: horizon=null does NOT surface (post-migration state)" {
    _write_task_with_horizon "T-9103" "null"
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    drift_count=$(echo "$output" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('horizon_drift',[])))")
    [ "$drift_count" = "0" ]
}

@test "CTL-030 pass: horizon=~ does NOT surface (YAML null alias)" {
    _write_task_with_horizon "T-9104" "~"
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    drift_count=$(echo "$output" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('horizon_drift',[])))")
    [ "$drift_count" = "0" ]
}

@test "CTL-030 pass: absent horizon field does NOT surface (pre-template-era legitimate state)" {
    _write_task_with_horizon "T-9105" ""
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    drift_count=$(echo "$output" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('horizon_drift',[])))")
    [ "$drift_count" = "0" ]
}

@test "CTL-030: mixed corpus — only non-null/non-absent surface" {
    _write_task_with_horizon "T-9110" "now"      # drift
    _write_task_with_horizon "T-9111" "null"     # ok
    _write_task_with_horizon "T-9112" "next"     # drift
    _write_task_with_horizon "T-9113" ""         # ok (absent)
    _write_task_with_horizon "T-9114" "later"    # drift
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    drift_ids=$(echo "$output" | python3 -c "import sys,json; print(','.join(sorted(i['id'] for i in json.load(sys.stdin).get('horizon_drift',[]))))")
    [ "$drift_ids" = "T-9110,T-9112,T-9114" ]
}

@test "CTL-030: audit.sh integration — FAIL line surfaces task id + horizon value + migration command" {
    _write_task_with_horizon "T-9120" "now"
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section compliance 2>&1
    [[ "$output" == *"CTL-030"* ]]
    [[ "$output" == *"T-9120"* ]]
    [[ "$output" == *"migrate-horizon-null-completed"* ]]
}

@test "CTL-030: --section compliance fires CTL-030 (pre-push path)" {
    _write_task_with_horizon "T-9130" "now"
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section compliance 2>&1
    [[ "$output" == *"CTL-030"* ]]
    [[ "$output" == *"T-9130"* ]]
}

@test "CTL-030: --section oe-daily also fires CTL-030 (cron-daily path)" {
    _write_task_with_horizon "T-9131" "now"
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section oe-daily 2>&1
    [[ "$output" == *"CTL-030"* ]]
    [[ "$output" == *"T-9131"* ]]
}

@test "CTL-030: --section structure alone does NOT fire CTL-030 (gate granularity)" {
    _write_task_with_horizon "T-9132" "now"
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure 2>&1
    [[ "$output" != *"CTL-030"* ]]
}
