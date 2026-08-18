#!/usr/bin/env bats
# T-3061 (OBS-316/OBS-317): audit.sh WARN for unclosed-but-satisfied active
# tasks. Integration-level: runs the real audit.sh section against a fixture
# project, unlike t3061_unclosed_satisfied_scan.bats which exercises the
# Python detector directly.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ -f "$AUDIT" ] || skip "audit.sh not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed" \
             "$TEST_ROOT/.tasks/templates" "$TEST_ROOT/.context/working" \
             "$TEST_ROOT/.context/locks" "$TEST_ROOT/.context/audits" \
             "$TEST_ROOT/docs/reports"

    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_ROOT/.tasks/templates/default.md" 2>/dev/null || \
        echo "---" > "$TEST_ROOT/.tasks/templates/default.md"

    cd "$TEST_ROOT"
    git init -q
    git config user.email "test@local"
    git config user.name "test"
    git add .
    git commit -q -m "init"

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
    export FW_AUDIT_TIMEOUT=120
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

@test "T-3061: fully-satisfied started-work task → audit WARNs and never mutates the task" {
    cat > "$TEST_ROOT/.tasks/active/T-9101-satisfied.md" << 'EOF'
---
id: T-9101
name: "Satisfied but unclosed"
status: started-work
workflow_type: build
---
# T-9101

## Acceptance Criteria

### Agent
- [x] Shipped the thing

### Human
- [x] Confirmed already

## Verification

echo test

## Updates
EOF
    before_sha=$(md5sum "$TEST_ROOT/.tasks/active/T-9101-satisfied.md" | cut -d' ' -f1)

    run "$AUDIT" --section quality
    [ "$status" -le 1 ]
    [[ "$output" == *"T-9101"* ]]
    [[ "$output" == *"every Agent AC ticked"* ]]
    [[ "$output" == *"Candidates for close, not closures"* ]]

    # A2: never mutates the task file (no status change, no box ticked)
    after_sha=$(md5sum "$TEST_ROOT/.tasks/active/T-9101-satisfied.md" | cut -d' ' -f1)
    [ "$before_sha" = "$after_sha" ]
    grep -q "^status: started-work" "$TEST_ROOT/.tasks/active/T-9101-satisfied.md"

    # A1: report path is named and the report file exists
    report_path="$TEST_ROOT/.context/audits/unclosed-satisfied/LATEST.md"
    [ -f "$report_path" ]
    grep -q "T-9101" "$report_path"
}

@test "T-3061: task with outstanding Human AC → no WARN for that task" {
    cat > "$TEST_ROOT/.tasks/active/T-9102-pending-human.md" << 'EOF'
---
id: T-9102
name: "Pending human review"
status: started-work
workflow_type: build
---
# T-9102

## Acceptance Criteria

### Agent
- [x] Shipped the thing

### Human
- [ ] [REVIEW] Not confirmed yet

## Verification

echo test

## Updates
EOF
    run "$AUDIT" --section quality
    [ "$status" -le 1 ]
    [[ "$output" != *"T-9102"*"every Agent AC ticked"* ]]
}

@test "T-3061: no qualifying tasks → PASS line, no WARN" {
    cat > "$TEST_ROOT/.tasks/active/T-9103-open.md" << 'EOF'
---
id: T-9103
name: "Still open work"
status: started-work
workflow_type: build
---
# T-9103

## Acceptance Criteria

### Agent
- [ ] Not done yet

## Verification

echo test

## Updates
EOF
    run "$AUDIT" --section quality
    [ "$status" -le 1 ]
    [[ "$output" == *"No active tasks are satisfied-but-unclosed"* ]]
}

@test "T-3061: WARN, never FAIL (A5) — exit code stays at warn level" {
    cat > "$TEST_ROOT/.tasks/active/T-9104-satisfied.md" << 'EOF'
---
id: T-9104
name: "Satisfied but unclosed"
status: issues
workflow_type: build
---
# T-9104

## Acceptance Criteria

### Agent
- [x] Shipped the thing

## Verification

echo test

## Updates
EOF
    run "$AUDIT" --section quality
    # audit.sh exit codes: 0=pass, 1=warnings, 2=failures (per AGENT.md contract)
    [ "$status" -le 1 ]
    [[ "$output" == *"[WARN]"*"T-9104"* ]] || [[ "$output" == *"T-9104"*"[WARN]"* ]]
    [[ "$output" != *"[FAIL]"*"T-9104"* ]]
}

@test "T-3061: audit.sh parses cleanly under bash -n" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
}
