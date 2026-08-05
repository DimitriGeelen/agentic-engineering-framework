#!/usr/bin/env bats
# Regression tests for agents/healing/lib/resolve.sh indent handling (T-2672).
#
# Origin: 832 field report (their T-295, third instance of the vendor-boundary
# regression class L-213/L-214). Two defects, one root cause (a 2-space indent
# assumption baked into both the emitter and the max-id scanner):
#   (a) appends emitted a hard-coded 2-space-indented block — invalid YAML when
#       the file's top-level list sits at column 0;
#   (b) max-id scans matched only '^  - id:' — column-0 ids were invisible, so
#       every run re-minted the same id (duplicate-learnings class).
# Fix: detect the indent of the last existing entry and emit at that indent;
# widen scans to '^[[:space:]]*- id: (L|FP)-[0-9]+'.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/project"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    export PATTERNS_FILE="$CONTEXT_DIR/project/patterns.yaml"

    cat > "$TASKS_DIR/active/T-001-test-task.md" <<'EOF'
---
id: T-001
name: "test task"
status: issues
---

# T-001: test task

## Updates
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: run do_resolve in a fresh bash (mirrors healing.sh sourcing)
_resolve() {
    bash -c '
        set -euo pipefail
        RED="" GREEN="" YELLOW="" CYAN="" BLUE="" NC=""
        TASKS_DIR="$2" PATTERNS_FILE="$3" CONTEXT_DIR="$4"
        get_yaml_field() { grep "^${2}:" "$1" | head -1 | sed "s/^${2}: *//; s/^\"//; s/\"$//"; }
        source "$1/agents/healing/lib/resolve.sh"
        do_resolve T-001 --mitigation "test mitigation" --pattern "test-pattern"
    ' _ "$FRAMEWORK_ROOT" "$TASKS_DIR" "$PATTERNS_FILE" "$CONTEXT_DIR"
}

_write_learnings_col0() {
    cat > "$CONTEXT_DIR/project/learnings.yaml" <<'EOF'
learnings:

- id: L-004
  learning: "existing column-zero entry"
  source: test
EOF
}

_write_learnings_indented() {
    cat > "$CONTEXT_DIR/project/learnings.yaml" <<'EOF'
learnings:
  - id: L-005
    learning: "existing indented entry"
    source: test
EOF
}

_write_patterns_col0() {
    cat > "$PATTERNS_FILE" <<'EOF'
failure_patterns:

- id: FP-003
  pattern: "existing column-zero pattern"
  learned_from: T-000

success_patterns: []
EOF
}

_write_patterns_indented() {
    cat > "$PATTERNS_FILE" <<'EOF'
failure_patterns:
  - id: FP-007
    pattern: "existing indented pattern"
    learned_from: T-000

success_patterns: []
EOF
}

@test "learnings column-0 shape: id increments (no re-mint) and file stays valid YAML" {
    _write_learnings_col0
    _write_patterns_indented
    run _resolve
    [ "$status" -eq 0 ]
    grep -q "^- id: L-005$" "$CONTEXT_DIR/project/learnings.yaml"
    ! grep -q "^  - id: L-" "$CONTEXT_DIR/project/learnings.yaml"
    python3 -c "import yaml; yaml.safe_load(open('$CONTEXT_DIR/project/learnings.yaml'))"
}

@test "learnings indented shape: id increments at 2-space indent, valid YAML" {
    _write_learnings_indented
    _write_patterns_indented
    run _resolve
    [ "$status" -eq 0 ]
    grep -q "^  - id: L-006$" "$CONTEXT_DIR/project/learnings.yaml"
    python3 -c "import yaml; yaml.safe_load(open('$CONTEXT_DIR/project/learnings.yaml'))"
}

@test "patterns column-0 shape: FP id increments at column 0, valid YAML" {
    _write_learnings_indented
    _write_patterns_col0
    run _resolve
    [ "$status" -eq 0 ]
    grep -q "^- id: FP-004$" "$PATTERNS_FILE"
    ! grep -q "^  - id: FP-004" "$PATTERNS_FILE"
    python3 -c "import yaml; yaml.safe_load(open('$PATTERNS_FILE'))"
}

@test "patterns indented shape: FP id increments at 2-space indent, valid YAML" {
    _write_learnings_indented
    _write_patterns_indented
    run _resolve
    [ "$status" -eq 0 ]
    grep -q "^  - id: FP-008$" "$PATTERNS_FILE"
    python3 -c "import yaml; yaml.safe_load(open('$PATTERNS_FILE'))"
}
