#!/usr/bin/env bats
# T-2076 (T-2065 GO scope): arc_rescore standalone + auto-fire from approve-driver.
#
# Three contracts:
#   1. Standalone `fw arc rescore <slug>` runs the BVP estimator on every active
#      member task; reports count; exit 0.
#   2. `fw arc approve-driver` triggers arc_rescore automatically after the YAML
#      mutate succeeds — sovereignty boundary is the approval, rescore is the
#      consequence.
#   3. Zero active members → clean "(no active member tasks — skipped)" message,
#      exit 0. Unknown arc → "Error: arc '...' not found", exit 1.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/lib/arc.sh" ] || skip "lib/arc.sh not found"
    [ -f "$FRAMEWORK_ROOT/lib/arc_membership.sh" ] || skip "lib/arc_membership.sh not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.context/working" \
             "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed"

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
    # arc_rescore shells out to `fw bvp estimate` — stub it via FW_BIN so the
    # test stays hermetic (real estimator reads policy YAMLs, opens task files,
    # has its own setup costs). The stub appends a per-task call line so we can
    # assert which tasks the rescore visited.
    STUB_LOG="$TEST_ROOT/fw-bvp-calls.log"
    STUB_BIN="$TEST_ROOT/fw-stub"
    cat > "$STUB_BIN" <<STUB
#!/usr/bin/env bash
# Stub: capture 'bvp estimate <T-id>' calls; succeed by default. Set
# FW_BVP_STUB_FAIL=<T-id> to simulate failure on a specific task.
if [ "\$1" = "bvp" ] && [ "\$2" = "estimate" ]; then
    echo "estimate \$3" >> "$STUB_LOG"
    if [ -n "\${FW_BVP_STUB_FAIL:-}" ] && [ "\$3" = "\$FW_BVP_STUB_FAIL" ]; then
        exit 1
    fi
    exit 0
fi
exit 99  # unexpected stub call
STUB
    chmod +x "$STUB_BIN"
    export FW_BIN="$STUB_BIN"
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# Run an arc.sh snippet in a fresh subshell with PROJECT_ROOT pointing at the
# isolated test fixture. cd into the test root so any task-creation hooks find
# the right .tasks/ layout.
arc_sh() {
    bash -c "cd '$TEST_ROOT' && source '$FRAMEWORK_ROOT/lib/arc.sh' && $*"
}

mk_task() {
    local tid="$1" slug="$2" state="${3:-active}"
    cat > "$TEST_ROOT/.tasks/${state}/${tid}-stub.md" <<EOF
---
id: $tid
name: stub-$tid
arc_id: $slug
tags: []
---
EOF
}

mk_arc() {
    local slug="$1" status="${2:-draft}"
    cat > "$TEST_ROOT/.context/arcs/${slug}.yaml" <<EOF
id: arc-999
name: $slug
headline_mechanic: "user sees a mechanic fire visibly to confirm the slug works"
status: $status
scoped_drivers: []
proposed_scoped_drivers: []
EOF
}

# --- Contract 3a: zero active members ---

@test "T-2076: arc_rescore with zero member tasks emits skipped message + exit 0" {
    mk_arc emptyarc
    run arc_sh "arc_rescore emptyarc"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "no member tasks for arc 'emptyarc'"
}

# --- Contract 3a (subset): all members in completed/ → no active rescore ---

@test "T-2076: arc_rescore with only-completed members skips with active-members message" {
    mk_arc onlycompleted
    mk_task T-7001 onlycompleted completed
    mk_task T-7002 onlycompleted completed
    run arc_sh "arc_rescore onlycompleted"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "no active member tasks"
    # stub MUST NOT have been called for completed-only members
    [ ! -f "$STUB_LOG" ]
}

# --- Contract 3b: not-found exits 1 ---

@test "T-2076: arc_rescore with unknown arc exits 1 with clear error" {
    run arc_sh "arc_rescore arc-nonexistent"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Error: arc 'arc-nonexistent' not found"
}

# --- Contract 1: standalone rescore visits every active member ---

@test "T-2076: arc_rescore visits every active member exactly once" {
    mk_arc myarc
    mk_task T-7100 myarc active
    mk_task T-7101 myarc active
    mk_task T-7102 myarc completed
    run arc_sh "arc_rescore myarc"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK: rescored 2 active member task(s)"
    # Verify which tasks the stub saw
    [ -f "$STUB_LOG" ]
    grep -q "estimate T-7100" "$STUB_LOG"
    grep -q "estimate T-7101" "$STUB_LOG"
    ! grep -q "estimate T-7102" "$STUB_LOG"
}

# --- Contract 1 (failure path): partial failure reported, exit 1 ---

@test "T-2076: arc_rescore reports per-task failures and exits 1 if any failed" {
    mk_arc myarc
    mk_task T-7200 myarc active
    mk_task T-7201 myarc active
    export FW_BVP_STUB_FAIL=T-7201
    run arc_sh "arc_rescore myarc"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "WARN: estimator failed on T-7201"
    echo "$output" | grep -q "Rescored 1 task(s), 1 failed"
}

# --- Contract 1 (idempotency): re-running visits the same tasks again ---

@test "T-2076: arc_rescore is idempotent — re-running visits the same task set" {
    mk_arc myarc
    mk_task T-7300 myarc active
    run arc_sh "arc_rescore myarc"
    [ "$status" -eq 0 ]
    run arc_sh "arc_rescore myarc"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK: rescored 1 active member task(s)"
    # stub log accumulates BOTH runs — assert second visit happened
    [ "$(grep -c 'estimate T-7300' "$STUB_LOG")" -eq 2 ]
}

# --- Contract 2: approve-driver auto-fires rescore ---

@test "T-2076: approve-driver triggers rescore on the arc" {
    mk_arc myarc draft
    mk_task T-7400 myarc active
    run arc_sh "arc_approve_driver myarc 'reliability' --weight 4 --i-am-human"
    [ "$status" -eq 0 ]
    # The approve message AND the rescore summary BOTH appear in output
    echo "$output" | grep -q "OK: approved scoped driver 'reliability'"
    echo "$output" | grep -q "Rescoring member tasks of arc 'myarc'"
    echo "$output" | grep -q "OK: rescored 1 active member task(s)"
    # Stub saw the member task
    grep -q "estimate T-7400" "$STUB_LOG"
}

# --- Contract 2 (sovereignty): rescore failure does NOT roll back approval ---

@test "T-2076: rescore failure surfaces WARN but driver approval stands" {
    mk_arc myarc draft
    mk_task T-7500 myarc active
    export FW_BVP_STUB_FAIL=T-7500
    run arc_sh "arc_approve_driver myarc 'reliability' --weight 4 --i-am-human"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK: approved scoped driver 'reliability'"
    echo "$output" | grep -q "WARN: rescore reported a failure"
    # Driver was actually written to the YAML — approval stands
    grep -q "name: reliability" "$TEST_ROOT/.context/arcs/myarc.yaml"
}
