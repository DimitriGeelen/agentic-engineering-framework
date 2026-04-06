#!/usr/bin/env bats
# Unit tests for audit scan scripts (T-961)

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ACTIVE_SCAN="$FRAMEWORK_ROOT/agents/audit/active-task-scan.py"
COMPLETED_SCAN="$FRAMEWORK_ROOT/agents/audit/completed-task-scan.py"

setup() {
    export TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/active" "$TEST_DIR/completed" "$TEST_DIR/episodic" "$TEST_DIR/reports"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# --- active-task-scan.py ---

@test "active-task-scan runs with empty dir" {
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"total"* ]]
}

@test "active-task-scan detects missing fields" {
    cat > "$TEST_DIR/active/T-001-test.md" << 'EOF'
---
id: T-001
name: "Test"
---
# T-001
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [[ "$status" -eq 0 ]]
    # Should have compliance issues for missing fields
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d['compliance']['issues']) > 0, 'expected compliance issues'"
}

@test "active-task-scan detects valid task" {
    cat > "$TEST_DIR/active/T-002-valid.md" << 'EOF'
---
id: T-002
name: "Valid task with enough description text for the threshold"
description: "This is a valid description with enough characters to pass the quality check"
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-04-01T00:00:00Z
last_update: 2026-04-01T00:00:00Z
---
# T-002: Valid task

## Acceptance Criteria

- [x] Criterion one

## Verification

echo "test"

## Updates

### 2026-04-01 — created
- Created
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [[ "$status" -eq 0 ]]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['stats']['valid'] == 1"
}

@test "active-task-scan detects inception without artifact" {
    cat > "$TEST_DIR/active/T-003-inception.md" << 'EOF'
---
id: T-003
name: "Inception test"
description: "Inception task without research artifact for testing C-001 check"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-04-01T00:00:00Z
last_update: 2026-04-01T00:00:00Z
---
# T-003

## Updates

### 2026-04-01 — created
EOF
    run python3 "$ACTIVE_SCAN" "$TEST_DIR" "$TEST_DIR/reports"
    [[ "$status" -eq 0 ]]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['research']['c001_missing'] == 1"
}

# --- completed-task-scan.py ---

@test "completed-task-scan runs with empty dir" {
    run python3 "$COMPLETED_SCAN" "$TEST_DIR" "$TEST_DIR/episodic" "$TEST_DIR/reports"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"total"* ]]
}

@test "completed-task-scan detects missing episodic" {
    cat > "$TEST_DIR/completed/T-010-done.md" << 'EOF'
---
id: T-010
name: "Done task"
workflow_type: build
---
# T-010
EOF
    run python3 "$COMPLETED_SCAN" "$TEST_DIR" "$TEST_DIR/episodic" "$TEST_DIR/reports"
    [[ "$status" -eq 0 ]]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'T-010' in d['missing_episodic']"
}

@test "completed-task-scan passes with episodic present" {
    cat > "$TEST_DIR/completed/T-011-done.md" << 'EOF'
---
id: T-011
name: "Done with episodic"
workflow_type: build
---
# T-011
EOF
    touch "$TEST_DIR/episodic/T-011.yaml"
    run python3 "$COMPLETED_SCAN" "$TEST_DIR" "$TEST_DIR/episodic" "$TEST_DIR/reports"
    [[ "$status" -eq 0 ]]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'T-011' not in d['missing_episodic']"
}

@test "completed-task-scan detects unchecked AC" {
    cat > "$TEST_DIR/completed/T-012-unchecked.md" << 'EOF'
---
id: T-012
name: "Unchecked AC"
workflow_type: build
---
# T-012

## Acceptance Criteria

### Agent
- [ ] Not checked

### Human
- [ ] Human AC (should be skipped)

## Updates
EOF
    touch "$TEST_DIR/episodic/T-012.yaml"
    run python3 "$COMPLETED_SCAN" "$TEST_DIR" "$TEST_DIR/episodic" "$TEST_DIR/reports"
    [[ "$status" -eq 0 ]]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d['unchecked_ac']) == 1; assert d['unchecked_ac'][0]['id'] == 'T-012'"
}
