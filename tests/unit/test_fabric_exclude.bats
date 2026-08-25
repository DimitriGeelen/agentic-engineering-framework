#!/usr/bin/env bats
# T-1842 — fabric expand_patterns helper honours exclude:.
#
# Origin: Penelope (email-archive) T-1458 via framework:pickup offsets 5/6.
# Both do_scan (register.sh) and do_drift (drift.sh) read patterns: only and
# silently dropped exclude:. Penelope's .fabric had 5946/6339 (93.8%) junk
# node_modules cards undetected for ~22 days because the bug appears
# identically in both code paths.
#
# These tests pin:
#   - per-pattern exclude removes matching files
#   - top-level exclude removes matching files across all patterns
#   - without exclude, behaviour is unchanged
#   - duplicates across overlapping patterns are deduplicated
#   - register.sh + drift.sh both reference expand_patterns.py (source pin)

load ../test_helper

HELPER="${FRAMEWORK_ROOT}/agents/fabric/lib/expand_patterns.py"

_make_fixture() {
    # $1 = project dir, builds a synthetic tree:
    #   src/a.js, src/b.js
    #   src/node_modules/junk.js (target for exclude)
    #   web/foo.html, web/_partial.html
    local proj="$1"
    mkdir -p "$proj/src/node_modules/parcel-bundler/lib"
    mkdir -p "$proj/web"
    : > "$proj/src/a.js"
    : > "$proj/src/b.js"
    : > "$proj/src/node_modules/junk.js"
    : > "$proj/src/node_modules/parcel-bundler/lib/x.js"
    : > "$proj/web/foo.html"
    : > "$proj/web/_partial.html"
}

@test "T-1842: helper exists at agents/fabric/lib/expand_patterns.py" {
    test -f "$HELPER"
}

@test "T-1842: per-pattern exclude removes matching files" {
    local proj="$TEST_TEMP_DIR/proj1"
    mkdir -p "$proj"
    _make_fixture "$proj"
    mkdir -p "$proj/.fabric"
    cat > "$proj/.fabric/watch-patterns.yaml" <<'YAML'
patterns:
  - glob: "src/**/*.js"
    expected_type: script
    exclude:
      - "src/node_modules/**"
YAML

    run python3 "$HELPER" "$proj/.fabric/watch-patterns.yaml" "$proj"
    [ "$status" -eq 0 ]
    # Should match src/a.js and src/b.js but NOT anything under node_modules
    echo "$output" | grep -q "^src/a.js$"
    echo "$output" | grep -q "^src/b.js$"
    ! echo "$output" | grep -q "node_modules"
}

@test "T-1842: top-level exclude removes matching files across all patterns" {
    local proj="$TEST_TEMP_DIR/proj2"
    mkdir -p "$proj"
    _make_fixture "$proj"
    mkdir -p "$proj/.fabric"
    cat > "$proj/.fabric/watch-patterns.yaml" <<'YAML'
exclude:
  - "**/node_modules/**"
patterns:
  - glob: "src/**/*.js"
    expected_type: script
  - glob: "web/*.html"
    expected_type: template
YAML

    run python3 "$HELPER" "$proj/.fabric/watch-patterns.yaml" "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" != *"node_modules"* ]]
    echo "$output" | grep -q "^src/a.js$"
    echo "$output" | grep -q "^web/foo.html$"
}

@test "T-1842: without exclude, all matches are emitted (baseline preserved)" {
    local proj="$TEST_TEMP_DIR/proj3"
    mkdir -p "$proj"
    _make_fixture "$proj"
    mkdir -p "$proj/.fabric"
    cat > "$proj/.fabric/watch-patterns.yaml" <<'YAML'
patterns:
  - glob: "src/*.js"
    expected_type: script
YAML

    run python3 "$HELPER" "$proj/.fabric/watch-patterns.yaml" "$proj"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^src/a.js$"
    echo "$output" | grep -q "^src/b.js$"
}

@test "T-1842: per-pattern exclude — _*.html fragment case (framework's own shape)" {
    local proj="$TEST_TEMP_DIR/proj4"
    mkdir -p "$proj"
    _make_fixture "$proj"
    mkdir -p "$proj/.fabric"
    # Mirrors framework's own watch-patterns.yaml shape for templates
    cat > "$proj/.fabric/watch-patterns.yaml" <<'YAML'
patterns:
  - glob: "web/*.html"
    expected_type: template
    exclude:
      - "web/_*.html"
YAML

    run python3 "$HELPER" "$proj/.fabric/watch-patterns.yaml" "$proj"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^web/foo.html$"
    ! echo "$output" | grep -q "^web/_partial.html$"
}

@test "T-1842: helper deduplicates paths when patterns overlap" {
    local proj="$TEST_TEMP_DIR/proj5"
    mkdir -p "$proj"
    _make_fixture "$proj"
    mkdir -p "$proj/.fabric"
    cat > "$proj/.fabric/watch-patterns.yaml" <<'YAML'
patterns:
  - glob: "src/*.js"
    expected_type: script
  - glob: "src/**/*.js"
    expected_type: script
    exclude:
      - "src/node_modules/**"
YAML

    run python3 "$HELPER" "$proj/.fabric/watch-patterns.yaml" "$proj"
    [ "$status" -eq 0 ]
    # src/a.js should appear once, not twice
    local count
    count=$(echo "$output" | grep -c "^src/a.js$" || true)
    [ "$count" -eq 1 ]
}

@test "T-1842: register.sh do_scan references expand_patterns.py" {
    run grep -q "expand_patterns.py" "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
    [ "$status" -eq 0 ]
}

@test "T-1842: drift.sh do_drift references expand_patterns.py" {
    run grep -q "expand_patterns.py" "$FRAMEWORK_ROOT/agents/fabric/lib/drift.sh"
    [ "$status" -eq 0 ]
}

@test "T-1842: register.sh + drift.sh use the same helper invocation shape (DRY)" {
    # Both call sites must invoke expand_patterns.py with $LIB_DIR — if one
    # drifts to inlined python, the exclude class can recur in one path
    # independently again.
    run grep -q '\$LIB_DIR/expand_patterns.py' "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
    [ "$status" -eq 0 ]
    run grep -q '\$LIB_DIR/expand_patterns.py' "$FRAMEWORK_ROOT/agents/fabric/lib/drift.sh"
    [ "$status" -eq 0 ]
}

@test "T-1842: register.sh + drift.sh parse with bash -n" {
    run bash -n "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
    [ "$status" -eq 0 ]
    run bash -n "$FRAMEWORK_ROOT/agents/fabric/lib/drift.sh"
    [ "$status" -eq 0 ]
}

@test "T-1842: helper handles missing watch-patterns argv with usage message" {
    run python3 "$HELPER"
    [ "$status" -eq 3 ]
    echo "$output" | grep -qi "usage"
}
