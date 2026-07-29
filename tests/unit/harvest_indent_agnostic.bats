#!/usr/bin/env bats
# T-2676 — harvest.sh indent-agnostic entry greps (dead learnings/patterns
# sub-stages). Third instance of the indentation-assumption class (T-2672
# resolve.sh emit-indent, 832 T-295 field report). The old greps matched only
# '^    learning:' / '^    pattern:' (4-space) while the live capture path
# writes 2-space field lines under column-0 list items — harvest_learnings
# was a permanent no-op ("No learnings found in project").

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run harvest_learnings in a fresh bash with the lib sourced; echo the counter.
_run_harvest_learnings() {
    run bash -c "
        source '$FRAMEWORK_ROOT/lib/paths.sh' 2>/dev/null || true
        GREEN=''; CYAN=''; NC=''
        new_learnings=0; duplicates=0; dry_run=true; verbose=true
        source '$FRAMEWORK_ROOT/lib/harvest.sh' 2>/dev/null || true
        harvest_learnings '$1' '$2' 'test-project'
        echo \"new=\$new_learnings dup=\$duplicates\"
    "
}

@test "2-space (live capture shape) learnings are found" {
    cat > "$TEST_TEMP_DIR/learnings.yaml" <<'EOF'
learnings:
- id: L-001
  learning: "modern two-space entry"
  source: P-001
EOF
    _run_harvest_learnings "$TEST_TEMP_DIR/learnings.yaml" "$TEST_TEMP_DIR/fw.yaml"
    [[ "$output" != *"No learnings found in project"* ]]
    [[ "$output" == *"new=1"* ]]
}

@test "4-space (legacy shape) learnings are still found" {
    cat > "$TEST_TEMP_DIR/learnings.yaml" <<'EOF'
learnings:
  - id: L-002
    learning: "legacy four-space entry"
    source: P-001
EOF
    _run_harvest_learnings "$TEST_TEMP_DIR/learnings.yaml" "$TEST_TEMP_DIR/fw.yaml"
    [[ "$output" != *"No learnings found in project"* ]]
    [[ "$output" == *"new=1"* ]]
}

@test "mixed-shape file yields both entries" {
    cat > "$TEST_TEMP_DIR/learnings.yaml" <<'EOF'
learnings:
  - id: L-003
    learning: "legacy entry"
    source: P-001
- id: L-004
  learning: "modern entry"
  source: P-001
EOF
    _run_harvest_learnings "$TEST_TEMP_DIR/learnings.yaml" "$TEST_TEMP_DIR/fw.yaml"
    [[ "$output" == *"new=2"* ]]
}

@test "framework-side dedup catches both shapes" {
    cat > "$TEST_TEMP_DIR/learnings.yaml" <<'EOF'
learnings:
- id: L-005
  learning: "already known entry"
EOF
    cat > "$TEST_TEMP_DIR/fw.yaml" <<'EOF'
learnings:
- id: L-900
  learning: "already known entry"
EOF
    _run_harvest_learnings "$TEST_TEMP_DIR/learnings.yaml" "$TEST_TEMP_DIR/fw.yaml"
    [[ "$output" == *"new=0 dup=1"* ]]
}
