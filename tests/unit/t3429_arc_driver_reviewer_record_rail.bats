#!/usr/bin/env bats
# T-3429 (arc-006, D-586): the audit rail behind the default-add ruling.
#
# Arc-scoped drivers are added on a static reviewer's word now, not an operator
# click. That trade is only honest while the verdict stays on the entry — an
# `approved_by: reviewer:...` row with no `reviewer:` block reads exactly like a
# certified driver and carries no evidence anything was checked. Three legs:
# WARN (claim without usable verdict), PASS (claim with verdict), silent (no
# scoped drivers to speak about).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root "$PROJECT_ROOT"
    mkdir -p "$PROJECT_ROOT/.context/arcs"

    # Extract the rail from audit.sh and give it the audit's pass/warn shims, so
    # the test pins the shipped source rather than a copy that can drift.
    RAIL="$TEST_TEMP_DIR/rail.sh"
    {
        echo 'pass(){ echo "PASS: $1"; }'
        echo 'warn(){ echo "WARN: $1"; echo "WHY: $2"; echo "FIX: $3"; }'
        sed -n '/^check_arc_driver_reviewer_record() {/,/^check_arc_driver_reviewer_record$/p' \
            "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    } > "$RAIL"
    export RAIL
    [ -s "$RAIL" ]
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

run_rail() {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' bash '$RAIL'"
}

@test "T-3429 rail: WARNs on a reviewer-approved driver with no reviewer: block" {
    cat > "$PROJECT_ROOT/.context/arcs/arc-960.yaml" <<'YAML'
id: arc-960
status: in-progress
scoped_drivers:
  - name: no-block-driver
    weight: 4
    approved_by: reviewer:static-v1
YAML
    run_rail
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN: Arc scoped driver 'no-block-driver'"* ]]
    [[ "$output" == *"no reviewer: block"* ]]
    [[ "$output" == *"fw arc review-driver arc-960"* ]]
}

@test "T-3429 rail: WARNs on a reviewer: block whose verdict is fail, naming the checks" {
    cat > "$PROJECT_ROOT/.context/arcs/arc-961.yaml" <<'YAML'
id: arc-961
status: in-progress
scoped_drivers:
  - name: failed-verdict-driver
    weight: 4
    approved_by: reviewer:static-v1
    reviewer:
      verdict: fail
      checks:
        a: {check: scorable, verdict: fail, reason: no mechanism}
        b: {check: distinct, verdict: pass, reason: fine}
        c: {check: distinguishes, verdict: fail, reason: too short}
YAML
    run_rail
    [[ "$output" == *"WARN: Arc scoped driver 'failed-verdict-driver'"* ]]
    [[ "$output" == *"verdict: fail (a, c)"* ]]
}

@test "T-3429 rail: PASSes when every reviewer-approved driver carries its verdict" {
    cat > "$PROJECT_ROOT/.context/arcs/arc-962.yaml" <<'YAML'
id: arc-962
status: in-progress
scoped_drivers:
  - name: certified-driver
    weight: 4
    approved_by: reviewer:static-v1
    reviewer:
      verdict: pass
      checks:
        a: {check: scorable, verdict: pass, reason: spec validates}
        b: {check: distinct, verdict: pass, reason: no collision}
        c: {check: distinguishes, verdict: pass, reason: names D2}
      ts: '2026-09-22T00:00:00Z'
      reviewer_id: static-v1
  - name: human-approved-driver
    weight: 3
    approved_by: human
YAML
    run_rail
    [[ "$output" == *"PASS: Arc driver reviewer records: 2 scoped driver(s)"* ]]
    [ "$(printf '%s' "$output" | grep -c '^WARN:')" -eq 0 ]
}

@test "T-3429 rail: a human-approved driver with no reviewer: block is not WARNed about" {
    cat > "$PROJECT_ROOT/.context/arcs/arc-963.yaml" <<'YAML'
id: arc-963
status: in-progress
scoped_drivers:
  - name: legacy-driver
    weight: 4
YAML
    run_rail
    [ "$(printf '%s' "$output" | grep -c '^WARN:')" -eq 0 ]
    [[ "$output" == *"PASS:"* ]]
}

@test "T-3429 rail: silent when no in-progress arc has scoped drivers" {
    cat > "$PROJECT_ROOT/.context/arcs/arc-964.yaml" <<'YAML'
id: arc-964
status: in-progress
scoped_drivers: []
YAML
    run_rail
    [ -z "$output" ]
}

@test "T-3429 rail: closed and draft arcs are out of scope" {
    cat > "$PROJECT_ROOT/.context/arcs/arc-965.yaml" <<'YAML'
id: arc-965
status: closed
scoped_drivers:
  - name: retired-driver
    weight: 4
    approved_by: reviewer:static-v1
YAML
    run_rail
    [ -z "$output" ]
}
