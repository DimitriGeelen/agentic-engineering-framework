#!/usr/bin/env bats
# T-2906: fw context status counted learnings with grep "^  - id: L-", which
# matches nothing once learnings.yaml is in PyYAML's flat serialisation
# ("- application: …" / "  id: L-NNN"). Counts must come from the data, not
# from one textual layout of it, and an unparseable file must not read as 0.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project" "$CONTEXT_DIR/episodic" "$CONTEXT_DIR/handovers" "$CONTEXT_DIR/audits"
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
    ensure_context_dirs() { :; }
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/agents/context/lib/status.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "flat PyYAML serialisation of learnings is counted" {
    cat > "$CONTEXT_DIR/project/learnings.yaml" <<'EOF'
learnings:
- application: TBD
  date: 2026-04-13
  id: L-001
  learning: First
- application: TBD
  id: L-002
  learning: Second
- id: PL-001
  learning: promoted, not an L- entry
- observation: candidate one
EOF
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Learnings: 2 (+ 1 candidates)"* ]]
}

@test "indented serialisation of patterns, decisions and learnings is counted" {
    cat > "$CONTEXT_DIR/project/patterns.yaml" <<'EOF'
failure_patterns:
  - id: FP-001
    pattern: a
  - id: FP-002
    pattern: b
success_patterns:
  - id: SP-001
workflow_patterns:
  - id: WP-001
  - id: WP-002
  - id: WP-003
EOF
    cat > "$CONTEXT_DIR/project/decisions.yaml" <<'EOF'
decisions:
  - id: D-001
  - id: D-002
EOF
    cat > "$CONTEXT_DIR/project/learnings.yaml" <<'EOF'
learnings:
  - id: L-001
    learning: x
EOF
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Patterns: 2 failure, 1 success, 3 workflow"* ]]
    [[ "$output" == *"Decisions: 2"* ]]
    [[ "$output" == *"Learnings: 1 (+ 0 candidates)"* ]]
}

@test "unparseable learnings.yaml reports ? and a reason, not 0" {
    printf 'learnings:\n- id: L-001\n  learning: "unterminated\n' > "$CONTEXT_DIR/project/learnings.yaml"
    run do_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Learnings: ? (+ ? candidates)"* ]]
    [[ "$output" == *"cannot count learnings.yaml"* ]]
    [[ "$output" != *"Learnings: 0"* ]] || false
}
