#!/usr/bin/env bats
# T-1870 / CTL-028: completed/ frontmatter status consistency
#
# L-390: tasks moved to .tasks/completed/ via `git mv` (rather than
# `fw task update --status work-completed`) leave frontmatter status
# desynced (typically status=started-work + date_finished=null).
# CTL-012 catches the AC consequence but not the bare metadata desync.
#
# This test exercises the completed-task-scan.py directly — it's the
# single source of truth for status_desync detection. The audit.sh
# CTL-028 block just renders the scanner's output as WARN lines.

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

# Helper: write a minimal completed-task md file
_write_task() {
    local id="$1" status="$2"
    cat > "$TMPREPO/.tasks/completed/${id}-test.md" <<EOF
---
id: $id
name: "test task"
status: $status
workflow_type: build
owner: agent
horizon: now
created: 2026-05-15T00:00:00Z
last_update: 2026-05-15T00:00:00Z
date_finished: 2026-05-15T00:00:00Z
---

# $id: test task

## Acceptance Criteria

### Agent
- [x] Done

## Verification
EOF
}

@test "CTL-028 pass: well-formed completed task with status=work-completed produces no desync" {
    _write_task "T-9001" "work-completed"
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    # Parse output and assert status_desync is empty
    desync_count=$(echo "$output" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('status_desync',[])))")
    [ "$desync_count" = "0" ]
}

@test "CTL-028 fail: completed task with status=started-work surfaces in status_desync" {
    _write_task "T-9002" "started-work"
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    desync_count=$(echo "$output" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('status_desync',[])))")
    [ "$desync_count" = "1" ]
    # Verify the specific entry shape: {id, status}
    entry=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin)['status_desync'][0]; print(f\"{d['id']}|{d['status']}\")")
    [ "$entry" = "T-9002|started-work" ]
}

@test "CTL-028: mixed dir — only desyncs surface" {
    _write_task "T-9010" "work-completed"
    _write_task "T-9011" "started-work"
    _write_task "T-9012" "captured"
    _write_task "T-9013" "work-completed"
    run python3 "$SCAN" "$TMPREPO/.tasks" "$TMPREPO/.context/episodic" "$TMPREPO/docs/reports"
    [ "$status" -eq 0 ]
    desync_ids=$(echo "$output" | python3 -c "import sys,json; print(','.join(sorted(i['id'] for i in json.load(sys.stdin).get('status_desync',[]))))")
    [ "$desync_ids" = "T-9011,T-9012" ]
}

@test "CTL-028: audit.sh integration — WARN line surfaces task id + observed status" {
    # Drive audit.sh against a tmp PROJECT_ROOT with one desynced task.
    # We don't run the full audit (slow) — just grep the relevant block.
    # Approach: invoke audit.sh with PROJECT_ROOT pointing at TMPREPO and
    # confirm CTL-028 WARN appears in output.
    _write_task "T-9020" "started-work"
    # Minimal scaffolding so audit.sh doesn't bail on missing dirs
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" 2>&1
    # audit.sh exits 1 (warnings) or 2 (failures) — both ok for this assertion
    [[ "$output" == *"CTL-028"* ]]
    [[ "$output" == *"T-9020"* ]]
    [[ "$output" == *"started-work"* ]]
}

# T-1882 section-gating regression tests
# CTL-028 was promoted from oe-daily-only to (compliance || oe-daily) so the
# pre-push audit (which includes compliance) catches status-drift class BEFORE
# the drift ships, rather than waiting up to 24h for the next oe-daily cron run.

@test "CTL-028 T-1882: --section compliance fires CTL-028 (pre-push path)" {
    _write_task "T-9030" "started-work"
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section compliance 2>&1
    [[ "$output" == *"CTL-028"* ]]
    [[ "$output" == *"T-9030"* ]]
}

@test "CTL-028 T-1882: --section oe-daily still fires CTL-028 (no regression)" {
    _write_task "T-9031" "started-work"
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section oe-daily 2>&1
    [[ "$output" == *"CTL-028"* ]]
    [[ "$output" == *"T-9031"* ]]
}

@test "CTL-028 T-1882: pre-push profile (structure,compliance,quality,discovery) fires CTL-028" {
    _write_task "T-9032" "started-work"
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure,compliance,quality,discovery 2>&1
    [[ "$output" == *"CTL-028"* ]]
    [[ "$output" == *"T-9032"* ]]
}

@test "CTL-028 T-1882: --section structure alone does NOT fire CTL-028 (gate granularity)" {
    # structure section is intentionally fast for pre-push; CTL-028 lives in
    # compliance. Verify the gate respects this — running structure alone
    # must not invoke CTL-028 (avoids loading completed-task-scan when not needed).
    _write_task "T-9033" "started-work"
    mkdir -p "$TMPREPO/.git" "$TMPREPO/agents/audit"
    cp "$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py" "$TMPREPO/agents/audit/"
    cp "$FRAMEWORK_ROOT/agents/audit/active-task-scan.py" "$TMPREPO/agents/audit/" 2>/dev/null || true

    cd "$TMPREPO"
    run env PROJECT_ROOT="$TMPREPO" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure 2>&1
    # No CTL-028 line at all — gate filtered it out
    [[ "$output" != *"CTL-028"* ]]
}
