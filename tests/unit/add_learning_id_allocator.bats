#!/usr/bin/env bats
# T-1369: add-learning ID allocator handles BOTH legacy indented-format
# (`  id: L-XXX`, where `- application:` opens the list item) and new
# dash-prefix format (`- id: L-XXX`).
#
# Before the fix, grep for `^- id: L-` missed 234 legacy entries, so every
# new add-learning call issued an ID that collided with historical IDs.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJECT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT/.context/project" "$PROJECT/.context/working" "$PROJECT/.tasks/active"
    touch "$PROJECT/.framework.yaml"
    export PROJECT_ROOT="$PROJECT"
    # Seed a started-work task so the gate is happy
    cat > "$PROJECT/.tasks/active/T-500-seed.md" <<EOF
---
id: T-500
status: started-work
workflow_type: build
owner: agent
---
EOF
    printf "current_task: T-500\n" > "$PROJECT/.context/working/focus.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_seed_legacy_learnings() {
    # Legacy indented format: `- application:` opens the item, `id:` is indented
    cat > "$PROJECT/.context/project/learnings.yaml" <<'EOF'
# Project Learnings
learnings:
- application: TBD
  context: Example
  date: 2026-04-01
  id: PL-001
  learning: First
  source: P-001
  task: T-100
- application: TBD
  context: Example
  date: 2026-04-01
  id: PL-050
  learning: Fifty
  source: P-001
  task: T-150
- application: TBD
  context: Example
  date: 2026-04-01
  id: PL-234
  learning: Last legacy entry
  source: P-001
  task: T-200
EOF
}

@test "add-learning: allocates next ID above legacy indented entries (regression T-1369)" {
    _seed_legacy_learnings
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" context add-learning "test learning" --task T-500 --source P-001
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PL-235"
    # And the file must now contain PL-235 as a new dash-prefix entry
    grep -qE "^- id: PL-235" "$PROJECT/.context/project/learnings.yaml"
}

@test "add-learning: continues from dash-prefix max when no legacy entries" {
    cat > "$PROJECT/.context/project/learnings.yaml" <<'EOF'
# Project Learnings
learnings:
- id: PL-010
  learning: "x"
  source: P-001
  task: T-100
  date: 2026-04-01
  context: Added
  application: TBD
EOF
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" context add-learning "next" --task T-500 --source P-001
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PL-011"
}

@test "add-learning: with mixed legacy+dash, picks max across BOTH" {
    cat > "$PROJECT/.context/project/learnings.yaml" <<'EOF'
# Project Learnings
learnings:
- application: TBD
  context: legacy
  date: 2026-04-01
  id: PL-234
  learning: "legacy max"
  source: P-001
  task: T-200
- id: PL-050
  learning: "new format but lower"
  source: P-001
  task: T-201
  date: 2026-04-01
  context: dash
  application: TBD
EOF
    cd "$PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" context add-learning "should be 235" --task T-500 --source P-001
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PL-235"
}
