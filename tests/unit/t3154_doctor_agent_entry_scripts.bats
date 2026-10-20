#!/usr/bin/env bats
# T-3154 — fw doctor's "Agent scripts executable" check iterated a hardcoded
# seven-item list and then printed "All agent scripts executable". A consumer
# (001-CashWeb) measured agents/designer/designer.sh at mode 644 in the same
# run that doctor reported OK: the verdict named a set it never ran over.
#
# The check now enumerates entry scripts from disk via agent_entry_scripts
# (lib/exec-bit-drift.sh). These tests pin the enumerator against a temp
# agents dir (so the real repo's modes are never touched) and the doctor
# wiring against the live tree.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    A="$TEST_TEMP_DIR/agents"
    mkdir -p "$A/audit" "$A/designer" "$A/task-create" "$A/context/lib"
    for f in audit/audit.sh designer/designer.sh task-create/create-task.sh \
             task-create/update-task.sh context/lib/focus.sh; do
        printf '#!/bin/bash\n' > "$A/$f"
    done
    chmod +x "$A/audit/audit.sh" "$A/designer/designer.sh" "$A/task-create/create-task.sh"
    source "$FRAMEWORK_ROOT/lib/exec-bit-drift.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "agent_entry_scripts enumerates <name>/<name>.sh from disk, including agents outside the old list" {
    run agent_entry_scripts "$A"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx "designer/designer.sh"
    echo "$output" | grep -qx "audit/audit.sh"
    echo "$output" | grep -qx "task-create/create-task.sh"
}

@test "agent_entry_scripts excludes sourced libs and helper scripts (mutation control)" {
    run agent_entry_scripts "$A"
    ! echo "$output" | grep -q "lib/focus.sh" || false
    ! echo "$output" | grep -q "update-task.sh" || false
    [ "$(echo "$output" | grep -c .)" -eq 3 ]
}

@test "a 644 entry script outside the old seven-item list is found by the doctor loop shape" {
    chmod 644 "$A/designer/designer.sh"
    local bad=""
    while IFS= read -r s; do
        [ -x "$A/$s" ] || bad="$bad $s"
    done < <(agent_entry_scripts "$A")
    [ "$bad" = " designer/designer.sh" ]
}

@test "doctor's Check 7 runs over the enumerator and states its count (wiring)" {
    grep -q 'done < <(agent_entry_scripts "\$AGENTS_DIR")' "$FRAMEWORK_ROOT/bin/fw"
    ! grep -q 'for agent in audit/audit.sh context/context.sh' "$FRAMEWORK_ROOT/bin/fw" || false
    cd "$FRAMEWORK_ROOT"
    run "$FRAMEWORK_ROOT/bin/fw" doctor --quick
    n=$(agent_entry_scripts "$FRAMEWORK_ROOT/agents" | grep -c .)
    echo "$output" | grep -q "All $n agent entry scripts executable"
}
