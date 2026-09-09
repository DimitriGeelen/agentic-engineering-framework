#!/usr/bin/env bats
# T-1856 (T-NEW-8): anchor_task existence audit check.
#
# When an arc YAML declares anchor_task: T-XXX and that task does not exist
# in .tasks/{active,completed}/, audit emits a WARN — never FAIL.
# Symmetric to T-1849's arc_id validation (which guards task→arc); this
# guards arc→task. Matches T-1846 §4 D4 (warn not block).
#
# T-3356 restructure. These tests previously drove `audit.sh --section structure`
# end-to-end. That section nests `timeout 300 bats tests/lint/` (108 invariants,
# audit.sh check_invariant_suite), so the file exceeded 180s even against an
# EMPTY fixture corpus and its four failure-path tests were killed mid-run —
# reported as reds when they were timeouts (T-3356 RCA; measured rc=124).
# Detection now lives in lib/audit-anchor-task.sh and is exercised directly;
# the last two tests pin that audit.sh still delivers it, so the extraction
# cannot silently become a detector nobody calls (the T-3302 failure class).

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    LIB="$FRAMEWORK_ROOT/lib/audit-anchor-task.sh"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$LIB" ] || skip "lib/audit-anchor-task.sh not found"
    # shellcheck source=/dev/null
    source "$LIB"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed"
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# --- happy path: anchor resolves ---

@test "T-1856: arc with valid anchor_task → counted, no finding" {
    cat > "$TEST_ROOT/.context/arcs/test-arc.yaml" <<'YAML'
id: test-arc
slug: test-arc
name: "test arc"
status: in-progress
anchor_task: T-1234
constituent_tasks: []
YAML
    cat > "$TEST_ROOT/.tasks/active/T-1234-stub.md" <<'MD'
---
id: T-1234
name: stub
---
MD
    run anchor_task_scan "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"MISSING"* ]]
    [[ "$output" == *"SUMMARY"$'\t'"1"$'\t'"0"* ]]
}

@test "T-1856: anchor resolving in completed/ counts as resolved" {
    cat > "$TEST_ROOT/.context/arcs/done-arc.yaml" <<'YAML'
id: done-arc
slug: done-arc
status: in-progress
anchor_task: T-4321
YAML
    printf -- '---\nid: T-4321\n---\n' > "$TEST_ROOT/.tasks/completed/T-4321-stub.md"
    run anchor_task_scan "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"MISSING"* ]]
    [[ "$output" == *"SUMMARY"$'\t'"1"$'\t'"0"* ]]
}

# --- failure path: anchor missing ---

@test "T-1856: arc with nonexistent anchor_task → MISSING finding, arc + id reported" {
    cat > "$TEST_ROOT/.context/arcs/orphan.yaml" <<'YAML'
id: orphan
slug: orphan
name: "orphan arc"
status: in-progress
anchor_task: T-99999
constituent_tasks: []
YAML
    run anchor_task_scan "$TEST_ROOT"
    # WARN-only contract: detection never signals failure via exit status.
    [ "$status" -eq 0 ]
    [[ "$output" == *"MISSING"$'\t'"orphan"$'\t'"T-99999"* ]]
    [[ "$output" == *"SUMMARY"$'\t'"1"$'\t'"1"* ]]
}

# --- silent for arcs without anchor ---

@test "T-1856: arc without anchor_task → not checked, not reported" {
    cat > "$TEST_ROOT/.context/arcs/noanchor.yaml" <<'YAML'
id: noanchor
slug: noanchor
name: "no anchor"
status: in-progress
constituent_tasks: []
YAML
    run anchor_task_scan "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"noanchor"* ]]
    # Nothing declared an anchor, so nothing was checked.
    [[ "$output" == *"SUMMARY"$'\t'"0"$'\t'"0"* ]]
}

# --- null anchor passes silently ---

@test "T-1856: arc with anchor_task: null → silent, treated as unset" {
    cat > "$TEST_ROOT/.context/arcs/nullanchor.yaml" <<'YAML'
id: nullanchor
slug: nullanchor
name: "null anchor"
status: in-progress
anchor_task: null
constituent_tasks: []
YAML
    run anchor_task_scan "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"nullanchor"* ]]
    [[ "$output" == *"SUMMARY"$'\t'"0"$'\t'"0"* ]]
}

# --- mix: one valid + one orphan → exactly one finding ---

@test "T-1856: mix of valid + orphan → only the orphan is reported" {
    cat > "$TEST_ROOT/.context/arcs/good.yaml" <<'YAML'
id: good
slug: good
status: in-progress
anchor_task: T-2222
YAML
    printf -- '---\nid: T-2222\n---\n' > "$TEST_ROOT/.tasks/active/T-2222-stub.md"
    cat > "$TEST_ROOT/.context/arcs/bad.yaml" <<'YAML'
id: bad
slug: bad
status: in-progress
anchor_task: T-99999
YAML
    run anchor_task_scan "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-99999"* ]]
    [[ "$output" != *"MISSING"$'\t'"good"* ]]
    [[ "$output" == *"SUMMARY"$'\t'"2"$'\t'"1"* ]]
}

# --- no arcs directory at all ---

@test "T-1856: absent .context/arcs → silent, zero checked" {
    rm -rf "$TEST_ROOT/.context/arcs"
    run anchor_task_scan "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUMMARY"$'\t'"0"$'\t'"0"* ]]
}

# --- delivery: the extraction must stay wired into audit.sh (T-3302 class) ---

@test "T-3356: audit.sh sources the lib and calls anchor_task_scan" {
    [ -f "$AUDIT" ] || skip "audit.sh not found"
    grep -q 'source "\$FRAMEWORK_ROOT/lib/audit-anchor-task.sh"' "$AUDIT"
    grep -q 'anchor_task_scan "\$PROJECT_ROOT"' "$AUDIT"
}

@test "T-3356: audit.sh still emits warn + pass_over for the anchor rule" {
    [ -f "$AUDIT" ] || skip "audit.sh not found"
    # The adapter must turn a MISSING record into a warn, and the all-clear
    # into pass_over. Without both, detection would run and report nothing.
    run bash -c "sed -n '/anchor_task_scan/,+0p;/MISSING)/,/^fi\$/p' '$AUDIT'"
    [[ "$output" == *"warn "* ]]
    [[ "$output" == *"pass_over "* ]]
    [[ "$output" == *"anchor_task"* ]]
}
