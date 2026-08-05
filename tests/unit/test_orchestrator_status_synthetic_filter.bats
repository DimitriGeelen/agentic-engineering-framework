#!/usr/bin/env bats
# T-1712 — fw orchestrator status: filter T-stress-* synthetic rows from
# enrichment metric, headline reports real dispatches only.
#
# Synthetic rows (task_id matching ^T-stress-) inflate the enrichment
# denominator and pollute task_type/worker_kind breakdowns with "?" values
# because they have no telemetry possible. The filter pins the split so the
# observability metric reflects real arc-substrate signal.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export PROJECT_ROOT
    mkdir -p "$PROJECT_ROOT/.context"
    FW_BIN="$FRAMEWORK_ROOT/bin/fw"
    [ -x "$FW_BIN" ]
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: write a dispatch row to the test PROJECT_ROOT's dispatches.jsonl.
_write_dispatch() {
    local task_id="$1" task_type="$2" worker_kind="$3" dispatch_id="$4"
    local d="$PROJECT_ROOT/.context/dispatches.jsonl"
    if [ "$task_type" = "null" ]; then
        local tt_json="null"
    else
        local tt_json="\"$task_type\""
    fi
    if [ "$worker_kind" = "null" ]; then
        local wk_json="null"
    else
        local wk_json="\"$worker_kind\""
    fi
    echo "{\"schema_version\": 1, \"ts\": \"2026-05-04T00:00:00Z\", \"dispatch_id\": \"$dispatch_id\", \"task_id\": \"$task_id\", \"task_type\": $tt_json, \"worker_kind\": $wk_json, \"outcome\": \"pending\"}" >> "$d"
}

_write_outcome() {
    local dispatch_id="$1"
    local o="$PROJECT_ROOT/.context/dispatch-outcomes.jsonl"
    echo "{\"schema_version\": 1, \"dispatch_id\": \"$dispatch_id\", \"outcome\": {\"verification_passed\": true, \"ac_satisfied\": true}}" >> "$o"
}

@test "headline excludes T-stress-* rows from dispatch_total" {
    _write_dispatch "T-1700" "default" "TermLink" "real-1"
    _write_dispatch "T-stress-0" "null" "null" "stress-1"
    _write_dispatch "T-stress-0" "null" "null" "stress-2"
    run "$FW_BIN" orchestrator status --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['dispatch_total'] == 1, f'expected 1 real, got {d[\"dispatch_total\"]}'
assert d['synthetic_total'] == 2, f'expected 2 synthetic, got {d[\"synthetic_total\"]}'
"
}

@test "enrichment_ratio is computed against real dispatches only" {
    _write_dispatch "T-1700" "default" "TermLink" "real-1"
    _write_outcome "real-1"
    # 50 synthetic rows with no outcomes — must NOT drag the ratio down.
    for i in $(seq 1 50); do
        _write_dispatch "T-stress-0" "null" "null" "stress-$i"
    done
    run "$FW_BIN" orchestrator status --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['enrichment_ratio'] == 1.0, f'expected 100% (1/1 real), got {d[\"enrichment_ratio\"]} ({d[\"enriched_dispatches\"]}/{d[\"dispatch_total\"]})'
assert d['synthetic_total'] == 50
"
}

@test "by_task_type breakdown excludes synthetic '?' rows" {
    _write_dispatch "T-1700" "default" "TermLink" "real-1"
    _write_dispatch "T-1701" "ollama-research" "ollama-loop" "real-2"
    for i in $(seq 1 10); do
        _write_dispatch "T-stress-0" "null" "null" "stress-$i"
    done
    run "$FW_BIN" orchestrator status --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# '?' should NOT dominate; only 'default' + 'ollama-research'.
assert '?' not in d['by_task_type'], f'? leaked into by_task_type: {d[\"by_task_type\"]}'
assert d['by_task_type'].get('default') == 1
assert d['by_task_type'].get('ollama-research') == 1
"
}

@test "stdout headline shows Synthetic: N when present" {
    _write_dispatch "T-1700" "default" "TermLink" "real-1"
    _write_dispatch "T-stress-0" "null" "null" "stress-1"
    run "$FW_BIN" orchestrator status
    [ "$status" -eq 0 ]
    echo "$output" | grep -qE "Dispatches:\s+1$"
    echo "$output" | grep -qE "Synthetic:\s+1\s+\(T-stress-\*"
}

@test "stdout omits Synthetic: line when no synthetic rows" {
    _write_dispatch "T-1700" "default" "TermLink" "real-1"
    run "$FW_BIN" orchestrator status
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "Synthetic:"
}

@test "all-synthetic case still emits substrate header (not 'no dispatches yet')" {
    _write_dispatch "T-stress-0" "null" "null" "stress-1"
    run "$FW_BIN" orchestrator status
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Dispatch substrate"
    echo "$output" | grep -qE "Synthetic:\s+1"
    # Real dispatches are 0 — Enriched line says so.
    echo "$output" | grep -qE "Enriched:\s+0/0"
}

@test "empty state still says 'no dispatches captured yet'" {
    run "$FW_BIN" orchestrator status
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "no dispatches captured yet"
}
