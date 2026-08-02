#!/usr/bin/env bats
# T-2723 (arc-015) — project-shape detection guard for F-10.
#
# Sibling of tests/unit/greenfield_seed_audit_prototype.bats (T-2703), which asks a
# DIFFERENT question. That one asks: once a project has been seeded greenfield, is the
# greenfield seed set internally consistent enough to pass its own audit? This one asks
# the question that precedes it: given a directory with real code in it, does `fw init`
# conclude "existing project" at all?
#
# The distinction matters because a misclassified project can pass the T-2703 prototype
# perfectly — the greenfield seed set is consistent with itself no matter which directory
# it was wrongly applied to. Seed-set health is not shape-detection health.
#
# F-10 (measured under T-2718, 2026-08-02): lib/init.sh consults a seven-entry manifest
# allowlist and three directory names, then treats ABSENCE OF A MATCH as positive evidence
# that the directory is empty. Every ecosystem off that list is seeded greenfield, which
# lands an owner:human inception task that the T-532 gate then uses to block all other
# edits — a first-run deadlock the agent is structurally forbidden to clear.
#
# EXPECTED STATE AT AUTHORING: RED on the four misclassifiers plus the two
# right-reason cases. That is deliberate — T-2722 implements the fix against this file,
# and a fix written before a provably-failing test is a fix that describes itself.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-shape-detect-XXXXXX)"
    mkdir -p "$TEST_TEMP_DIR/home"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# _shape_of <dir> — run the REAL `fw init` and report the shape it inferred.
#
# Echoes exactly "greenfield" or "existing" on success. On ANY path where the answer is
# not positively established it echoes a distinct marker and returns non-zero, so a
# broken/renamed output line can never be mistaken for a passing assertion. That is the
# same failure-mode discipline this whole file is about: absence of a match must not
# read as evidence of anything.
# Runs under `env -i` (L-009/L-020, T-1633): an inherited PROJECT_ROOT/FRAMEWORK_ROOT
# makes `fw` in a fresh directory silently operate on the WRONG project, and the whole
# point of this suite is what a user with no framework state sees on their first run.
_shape_of() {
    local proj="$1"
    local out
    if ! out=$(env -i \
            PATH="/usr/local/bin:/usr/bin:/bin" \
            HOME="$TEST_TEMP_DIR/home" \
            "$FRAMEWORK_ROOT/bin/fw" init "$proj" 2>&1); then
        echo "INIT_FAILED"
        return 1
    fi
    local line
    line=$(printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -F "onboarding tasks (" || true)
    if [ -z "$line" ]; then
        echo "NO_MODE_LINE"
        return 1
    fi
    case "$line" in
        *"(greenfield mode)"*)       echo "greenfield" ;;
        *"(existing project mode)"*) echo "existing" ;;
        *)                           echo "UNPARSEABLE"; return 1 ;;
    esac
}

_fixture() {
    local name="$1"
    local p="$TEST_TEMP_DIR/$name"
    mkdir -p "$p"
    printf '%s' "$p"
}

# ── The four F-10 misclassifiers ────────────────────────────────────────────────
# Real code, no allowlisted manifest, no incidental src//lib//app/ directory.

@test "shape: .NET solution is detected as an existing project" {
    local p; p=$(_fixture dotnet); mkdir -p "$p/MyApp"
    touch "$p/MyApp.sln" "$p/MyApp/MyApp.csproj" "$p/MyApp/Program.cs"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "existing" ]
}

@test "shape: C/C++ Makefile project is detected as an existing project" {
    local p; p=$(_fixture cpp); mkdir -p "$p/include"
    touch "$p/Makefile" "$p/main.c" "$p/include/foo.h"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "existing" ]
}

@test "shape: PHP composer project is detected as an existing project" {
    local p; p=$(_fixture php)
    touch "$p/composer.json" "$p/index.php"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "existing" ]
}

@test "shape: flat python with no manifest is detected as an existing project" {
    local p; p=$(_fixture flatpy)
    touch "$p/main.py" "$p/utils.py" "$p/README.md"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "existing" ]
}

# ── The two accidental passes, isolated ─────────────────────────────────────────
# T-2718 measured that ruby and gradle-java currently pass, but NOT because the
# detector recognises them — neither Gemfile nor build.gradle is on the allowlist.
# They pass only because those fixtures happened to contain app/ and src/. These two
# tests strip the incidental directory so the assertion turns on recognition alone.
# A green here that disappears when app//src/ is removed is a green produced by
# accident, which is indistinguishable from a green produced by recognition unless
# something asks the question this way.

@test "shape: ruby Gemfile project is recognised WITHOUT an incidental app/ directory" {
    local p; p=$(_fixture rubyflat); mkdir -p "$p/models"
    touch "$p/Gemfile" "$p/Rakefile" "$p/models/user.rb"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "existing" ]
}

@test "shape: gradle project is recognised WITHOUT an incidental src/ directory" {
    local p; p=$(_fixture gradleflat)
    touch "$p/build.gradle" "$p/settings.gradle" "$p/Main.java"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "existing" ]
}

# ── Currently-correct cases: these must stay green through T-2722's fix ─────────

@test "shape: node package.json project is detected as an existing project" {
    local p; p=$(_fixture node)
    touch "$p/package.json" "$p/index.js"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "existing" ]
}

@test "shape: rust Cargo project is detected as an existing project" {
    local p; p=$(_fixture rust); mkdir -p "$p/src"
    touch "$p/Cargo.toml" "$p/src/main.rs"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "existing" ]
}

@test "shape: a genuinely empty directory is detected as greenfield" {
    local p; p=$(_fixture empty)
    touch "$p/.keep"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" = "greenfield" ]
}

# ── Negative controls ───────────────────────────────────────────────────────────
# Without these, every assertion above could be satisfied by a helper that returns
# "existing" unconditionally, or by an output-parse that silently yields the empty
# string. Each control proves a specific way the suite could be green while blind.

@test "negative control: the empty fixture is NOT reported as existing" {
    local p; p=$(_fixture negempty)
    touch "$p/.keep"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" != "existing" ]
}

@test "negative control: a project that IS recognised is NOT reported as greenfield" {
    local p; p=$(_fixture negnode)
    touch "$p/package.json" "$p/index.js"
    run _shape_of "$p"
    [ "$status" -eq 0 ]
    [ "$output" != "greenfield" ]
}

@test "negative control: _shape_of fails loudly when the mode line cannot be found" {
    # Point the helper at a path `fw init` cannot seed. The requirement is not which
    # error occurs — it is that NO failure path yields a bare empty string that a
    # later `[ "$output" = ... ]` could accidentally satisfy.
    run _shape_of "$TEST_TEMP_DIR/nonexistent/deeply/nested"
    [ "$status" -ne 0 ]
    [ -n "$output" ]
    [ "$output" != "existing" ]
    [ "$output" != "greenfield" ]
}
