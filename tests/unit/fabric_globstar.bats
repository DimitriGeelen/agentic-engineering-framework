#!/usr/bin/env bats
# Regression: fabric drift/scan must enable shopt -s globstar so recursive
# `**` patterns from .fabric/watch-patterns.yaml match nested files (T-1320).
#
# Origin: termlink T-1130 pickup (P-037) → T-1319 inception (GO) → T-1320 build.
#
# Pre-fix bug: bash defaults treat `**` as `*`, so `crates/*/src/**/*.rs`
# matched only the immediate `src/` files, while `fw audit`'s Python glob
# (recursive=True) matched the nested ones — producing a divergence loop.

load ../test_helper

FABRIC="$FRAMEWORK_ROOT/agents/fabric/fabric.sh"

# --- Source-level invariants (cheap; catch reverts) ---

@test "drift.sh enables shopt -s globstar before its glob loop" {
    run grep -A20 '^do_drift' "$FRAMEWORK_ROOT/agents/fabric/lib/drift.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"shopt -s globstar"* ]]
}

@test "register.sh enables shopt -s globstar before its glob loop" {
    run grep -A30 '^do_scan' "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"shopt -s globstar"* ]]
}

# --- Behavior contract: what shopt -s globstar actually does ---

@test "default bash glob does NOT recurse with **" {
    mkdir -p "$TEST_TEMP_DIR/a/b/c"
    : > "$TEST_TEMP_DIR/a/b/c/deep.rs"
    : > "$TEST_TEMP_DIR/a/shallow.rs"
    cd "$TEST_TEMP_DIR"
    local matches
    matches=$(bash -c 'for f in a/**/*.rs; do echo "$f"; done')
    # Without globstar, `**` collapses to `*` — does not reach a/b/c/deep.rs.
    [[ "$matches" != *"deep.rs"* ]] || skip "Bash default already recurses on this platform"
}

@test "shopt -s globstar makes ** match nested directories" {
    mkdir -p "$TEST_TEMP_DIR/a/b/c"
    : > "$TEST_TEMP_DIR/a/b/c/deep.rs"
    : > "$TEST_TEMP_DIR/a/shallow.rs"
    cd "$TEST_TEMP_DIR"
    local matches
    matches=$(bash -c 'shopt -s globstar; for f in a/**/*.rs; do echo "$f"; done')
    [[ "$matches" == *"deep.rs"* ]]
    [[ "$matches" == *"shallow.rs"* ]]
}

# --- Integration: fw fabric scan registers a deeply-nested file ---

_setup_recursive_project() {
    local project="$TEST_TEMP_DIR/project"
    mkdir -p "$project/.fabric/components"
    mkdir -p "$project/src/api/v1/handlers"
    : > "$project/src/api/v1/handlers/deep.py"
    : > "$project/src/shallow.py"
    echo "framework_root: $FRAMEWORK_ROOT" > "$project/.framework.yaml"
    cat > "$project/.fabric/watch-patterns.yaml" <<'YAML'
patterns:
  - glob: "src/**/*.py"
    subsystem: api
YAML
    # Stub card so the existing-cards grep doesn't fail under set -e.
    printf 'name: stub\nlocation: stub.txt\n' > "$project/.fabric/components/stub.yaml"
    echo "$project"
}

@test "fabric scan registers deeply-nested file under recursive ** pattern" {
    PROJECT="$(_setup_recursive_project)"
    cd "$PROJECT"
    PROJECT_ROOT="$PROJECT" run "$FABRIC" scan
    [ "$status" -eq 0 ]
    # Pre-fix: only `shallow.py` would be registered; `deep.py` would be silently missed.
    [ -f "$PROJECT/.fabric/components/src-api-v1-handlers-deep.yaml" ]
    [ -f "$PROJECT/.fabric/components/src-shallow.yaml" ]
}

@test "fabric drift reports deeply-nested unregistered file" {
    PROJECT="$(_setup_recursive_project)"
    cd "$PROJECT"
    PROJECT_ROOT="$PROJECT" run "$FABRIC" drift
    # drift exits 0 normally even when drift is found
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    # Either the deeply-nested file is reported as unregistered, or the output
    # mentions src/api/v1/handlers — both prove globstar fired.
    [[ "$output" == *"deep.py"* ]] || [[ "$output" == *"handlers"* ]]
}
