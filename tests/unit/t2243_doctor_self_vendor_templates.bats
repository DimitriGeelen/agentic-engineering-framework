#!/usr/bin/env bats
# T-2243: fw doctor must detect drift in BOTH self-vendor classes —
# libs (`.agentic-framework/{bin,lib,agents,web}`, T-1434) AND templates
# (`.agentic-framework/.tasks/templates/*.md`, T-2241 sibling). T-2241
# shipped the templates self-vendor verb + pre-push gate; this closes
# the any-time inspection asymmetry where doctor saw libs class only.
#
# Tests assert per-class WARN visibility — the WARN block carries each
# class's own count and example list.

load ../test_helper

# T-3778: the check is lib/doctor-drift.sh doctor_check_vendored_drift <root>.
# These tests run it on a FIXTURE root instead of a whole `bin/fw doctor` per test:
# four doctor runs crossed the 900 s per-file cap (848 s on the 2026-10-21
# nightly), and appending to the LIVE .agentic-framework/.tasks/templates/default.md
# raced concurrent `fw vendor self` workers (the fedc2ffd1 flake). Doctor's wiring
# is proven by the real run in doctor_designer_pin_drift.bats t1 and pinned
# structurally in t5 below.

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    ROOT="$TEST_TEMP_DIR/fw"
    mkdir -p "$ROOT"/{bin,lib,agents,web} "$ROOT/.tasks/templates" "$ROOT/.tasks/workflow" \
             "$ROOT"/.agentic-framework/{bin,lib,agents,web} \
             "$ROOT/.agentic-framework/.tasks/templates" "$ROOT/.agentic-framework/.tasks/workflow"
    local i
    for i in 1 2 3 4 5 6 7; do
        echo "echo $i" > "$ROOT/lib/l$i.sh"
        cp "$ROOT/lib/l$i.sh" "$ROOT/.agentic-framework/lib/l$i.sh"
    done
    echo "# default" > "$ROOT/.tasks/templates/default.md"
    echo "# build" > "$ROOT/.tasks/templates/build.md"
    cp "$ROOT/.tasks/templates/"*.md "$ROOT/.agentic-framework/.tasks/templates/"
    TPL_SENTINEL="$ROOT/.agentic-framework/.tasks/templates/default.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Run the check exactly as doctor does (same colour vars, same counter).
_vdrift() {
    run bash -c 'GREEN= YELLOW= CYAN= NC= warnings=0
        source "$1/lib/doctor-drift.sh"; doctor_check_vendored_drift "$2"; echo "warnings=$warnings"' \
        _ "$FRAMEWORK_ROOT" "$ROOT"
    [ "$status" -eq 0 ]
}

@test "t2243 t1: no templates drift → templates class absent from WARN list" {
    _vdrift
    [[ "$output" == *"No vendored-source drift"* ]]
    [[ "$output" != *"templates ("* ]]
    [[ "$output" == *"warnings=0"* ]]
}

@test "t2243 t2: templates-only drift → 'templates (N)' line in WARN" {
    echo "<!-- T-2243 templates drift sentinel -->" >> "$TPL_SENTINEL"
    _vdrift
    [[ "$output" == *"Vendored-source drift: 1 file(s) out of sync"* ]]
    [[ "$output" == *"templates (1)"* ]]
    [[ "$output" == *".tasks/templates/default.md"* ]]
    [[ "$output" != *"libs ("* ]]
    [[ "$output" == *"warnings=1"* ]]
}

@test "t2243 t3: per-class split — libs drift cannot bury templates drift" {
    # The T-2243 defect: >5 libs drifts filled the single "first 5" bucket and hid
    # the templates drift. With 7 libs drifting, templates must still be listed.
    local i
    for i in 1 2 3 4 5 6 7; do echo "# drift" >> "$ROOT/.agentic-framework/lib/l$i.sh"; done
    echo "<!-- T-2243 split-check sentinel -->" >> "$TPL_SENTINEL"
    _vdrift
    [[ "$output" == *"Vendored-source drift: 8 file(s) out of sync"* ]]
    [[ "$output" == *"libs (7) — first 5:"* ]]
    [[ "$output" == *"templates (1) — first 1:"* ]]
    [[ "$output" == *".tasks/templates/default.md"* ]]
}

@test "t2243 t4: drift message stays class-agnostic — 'fw vendor' remediation" {
    echo "<!-- T-2243 remediation-check sentinel -->" >> "$TPL_SENTINEL"
    _vdrift
    [[ "$output" == *"Run: fw vendor"* ]]
}

@test "t2243 t5: doctor calls the lib check for the framework repo only" {
    # Wiring, pinned in source (the real doctor run lives in
    # doctor_designer_pin_drift.bats t1, which asserts this check's line too).
    run grep -A2 -F 'if [ "$PROJECT_ROOT" = "$FRAMEWORK_ROOT" ]; then' "$FRAMEWORK_ROOT/bin/fw"
    [[ "$output" == *'doctor_check_vendored_drift "$FRAMEWORK_ROOT"'* ]]
    run grep -c 'source "$FRAMEWORK_ROOT/lib/doctor-drift.sh"' "$FRAMEWORK_ROOT/bin/fw"
    [ "$output" -eq 1 ]
}
