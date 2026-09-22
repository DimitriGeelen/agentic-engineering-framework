#!/usr/bin/env bats
# Regression: fabric drift/scan must expand recursive `**` patterns from
# .fabric/watch-patterns.yaml so nested files match (T-1320). Originally via
# `shopt -s globstar` in bash; since T-1842 via expand_patterns.py
# (glob.glob(..., recursive=True)) — see the source-level section (T-3436).
#
# Origin: termlink T-1130 pickup (P-037) → T-1319 inception (GO) → T-1320 build.
#
# Pre-fix bug: bash defaults treat `**` as `*`, so `crates/*/src/**/*.rs`
# matched only the immediate `src/` files, while `fw audit`'s Python glob
# (recursive=True) matched the nested ones — producing a divergence loop.

load ../test_helper

FABRIC="$FRAMEWORK_ROOT/agents/fabric/fabric.sh"

# --- Source-level invariants (cheap; catch reverts) ---
# T-1842 (4a1c95d0c, 2026-05-15) replaced the bash `shopt -s globstar` + glob
# loop in do_drift and do_scan with a delegation to expand_patterns.py, which
# globs with recursive=True. Same invariant (`**` recurses), different mechanism.
# T-3436: the two tests here used to grep for the bash line and were red for
# 130 days after T-1842 without anyone noticing (OBS-392: the nightly unit suite
# never completes). Pin the mechanism that exists, not the one that was removed —
# and pin it over the whole function body, not an -A<N> window that the next
# insertion above the call silently pushes the line out of.

@test "drift.sh do_drift delegates pattern expansion to expand_patterns.py (T-1842)" {
    run sed -n '/^do_drift()/,/^}/p' "$FRAMEWORK_ROOT/agents/fabric/lib/drift.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"expand_patterns.py"* ]]
    [[ "$output" != *"shopt -s globstar"* ]]
}

@test "register.sh do_scan delegates pattern expansion to expand_patterns.py (T-1842)" {
    run sed -n '/^do_scan()/,/^}/p' "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"expand_patterns.py"* ]]
    [[ "$output" != *"shopt -s globstar"* ]]
}

@test "expand_patterns.py globs with recursive=True so ** reaches nested files" {
    run grep -c 'glob.glob(.*recursive=True' "$FRAMEWORK_ROOT/agents/fabric/lib/expand_patterns.py"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
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
