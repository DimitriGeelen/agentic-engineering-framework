#!/usr/bin/env bats
# Unit tests for lib/build.sh — TypeScript compilation via esbuild
#
# Tests: early exits (no src, no .ts), stale guard, verbose flag, npx missing

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT="$TEST_TEMP_DIR/fw"
    mkdir -p "$FRAMEWORK_ROOT/lib"
    # Copy build.sh to temp framework
    cp "$(_find_framework_root)/lib/build.sh" "$FRAMEWORK_ROOT/lib/build.sh"
    chmod +x "$FRAMEWORK_ROOT/lib/build.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: find real framework root
_find_framework_root() {
    local dir="$BATS_TEST_DIRNAME"
    while [ "$dir" != "/" ]; do
        [ -d "$dir/agents" ] && [ -f "$dir/FRAMEWORK.md" ] && { echo "$dir"; return; }
        dir="$(dirname "$dir")"
    done
    echo "$BATS_TEST_DIRNAME"
}

# ── No src directory ────────────────────────────────────────

@test "build: exits 0 when no src directory exists" {
    # No lib/ts/src dir — should exit cleanly
    run bash "$FRAMEWORK_ROOT/lib/build.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── No .ts files ────────────────────────────────────────────

@test "build: exits 0 when src dir exists but has no .ts files" {
    mkdir -p "$FRAMEWORK_ROOT/lib/ts/src"
    # Empty src directory
    run bash "$FRAMEWORK_ROOT/lib/build.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "build: exits 0 when src has only non-ts files" {
    mkdir -p "$FRAMEWORK_ROOT/lib/ts/src"
    echo "console.log('js')" > "$FRAMEWORK_ROOT/lib/ts/src/test.js"
    run bash "$FRAMEWORK_ROOT/lib/build.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Stale guard ─────────────────────────────────────────────

@test "build: stale guard skips when output is newer than source" {
    mkdir -p "$FRAMEWORK_ROOT/lib/ts/src" "$FRAMEWORK_ROOT/lib/ts/dist"
    echo "const x = 1;" > "$FRAMEWORK_ROOT/lib/ts/src/test.ts"
    # Make dist newer than src
    sleep 0.1
    echo "compiled" > "$FRAMEWORK_ROOT/lib/ts/dist/test.js"

    run bash "$FRAMEWORK_ROOT/lib/build.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "build: stale guard with --verbose shows up-to-date message" {
    mkdir -p "$FRAMEWORK_ROOT/lib/ts/src" "$FRAMEWORK_ROOT/lib/ts/dist"
    echo "const x = 1;" > "$FRAMEWORK_ROOT/lib/ts/src/test.ts"
    sleep 0.1
    echo "compiled" > "$FRAMEWORK_ROOT/lib/ts/dist/test.js"

    run bash "$FRAMEWORK_ROOT/lib/build.sh" --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"all up to date"* ]]
}

# ── Build needed ────────────────────────────────────────────

@test "build: detects when output is missing (needs build)" {
    mkdir -p "$FRAMEWORK_ROOT/lib/ts/src"
    echo "const x = 1;" > "$FRAMEWORK_ROOT/lib/ts/src/test.ts"
    # No dist dir — build is needed

    # This will try to run npx, which should succeed in our env
    run bash "$FRAMEWORK_ROOT/lib/build.sh"
    # Should either succeed (npx available) or fail with npx error
    # We just verify it tried to build (didn't skip silently)
    if [ "$status" -eq 0 ]; then
        [[ "$output" == *"compiled"* ]]
    else
        [[ "$output" == *"npx"* ]] || [[ "$output" == *"esbuild"* ]]
    fi
}

@test "build: detects when source is newer than output (needs rebuild)" {
    mkdir -p "$FRAMEWORK_ROOT/lib/ts/src" "$FRAMEWORK_ROOT/lib/ts/dist"
    echo "old" > "$FRAMEWORK_ROOT/lib/ts/dist/test.js"
    sleep 0.1
    echo "const x = 2;" > "$FRAMEWORK_ROOT/lib/ts/src/test.ts"

    run bash "$FRAMEWORK_ROOT/lib/build.sh"
    # Should detect stale output and attempt build
    if [ "$status" -eq 0 ]; then
        [[ "$output" == *"compiled"* ]]
    else
        [[ "$output" == *"npx"* ]] || [[ "$output" == *"esbuild"* ]]
    fi
}
