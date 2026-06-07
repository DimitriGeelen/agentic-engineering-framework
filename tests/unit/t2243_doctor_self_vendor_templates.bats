#!/usr/bin/env bats
# T-2243: fw doctor must detect drift in BOTH self-vendor classes —
# libs (`.agentic-framework/{bin,lib,agents,web}`, T-1434) AND templates
# (`.agentic-framework/.tasks/templates/*.md`, T-2241 sibling). T-2241
# shipped the templates self-vendor verb + pre-push gate; this closes
# the any-time inspection asymmetry where doctor saw libs class only.
#
# Tests assert per-class WARN visibility — the framework repo has
# pre-existing libs drift in normal day-to-day state (the .agentic-framework
# tree only re-syncs on `fw vendor`, not every edit), so tests cannot
# require "No vendored-source drift" globally. Instead they assert the
# WARN block carries each class's own count and example list.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    TPL_SENTINEL="$FRAMEWORK_ROOT/.agentic-framework/.tasks/templates/default.md"
    [ -f "$TPL_SENTINEL" ] || skip ".agentic-framework/.tasks/templates/default.md missing"
    TPL_BACKUP="$TEST_TEMP_DIR/default.md.orig"
    cp "$TPL_SENTINEL" "$TPL_BACKUP"
}

teardown() {
    [ -f "$TPL_BACKUP" ] && cp "$TPL_BACKUP" "$TPL_SENTINEL"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "t2243 t1: no templates drift → templates class absent from WARN list" {
    # Setup restored the templates sentinel; libs may still drift but
    # the per-class split (T-2243) means templates count must be 0
    # in the WARN block — verified by absence of the `templates (N)` line.
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    [[ "$output" != *"templates (1)"* ]]
    [[ "$output" != *"templates (2)"* ]]
    [[ "$output" != *"templates (3)"* ]]
}

@test "t2243 t2: templates-only drift → 'templates (N)' line in WARN" {
    # Mutate the vendored template — should bump templates count by 1.
    echo "<!-- T-2243 templates drift sentinel -->" >> "$TPL_SENTINEL"
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"
    [[ "$output" == *"Vendored-source drift"* ]]
    [[ "$output" == *"templates ("* ]]
    [[ "$output" == *".tasks/templates/default.md"* ]]
}

@test "t2243 t3: per-class split — libs and templates counted separately" {
    # Mutate templates; existing libs drift is independent.
    # The per-class shape means templates visibility doesn't depend
    # on libs count (pre-T-2243 the global 'first 5' bucket could
    # bury templates when libs drift was >5).
    echo "<!-- T-2243 split-check sentinel -->" >> "$TPL_SENTINEL"
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"
    # Both class lines should be possible; templates definitely present
    [[ "$output" == *"templates ("* ]]
    [[ "$output" == *"first 1:"* ]]  # exactly 1 templates drift introduced
}

@test "t2243 t4: drift message stays class-agnostic — 'fw vendor' remediation" {
    echo "<!-- T-2243 remediation-check sentinel -->" >> "$TPL_SENTINEL"
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"
    [[ "$output" == *"Run: fw vendor"* ]]
}
