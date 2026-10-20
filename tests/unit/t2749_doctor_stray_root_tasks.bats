#!/usr/bin/env bats
# T-2749 — fw doctor's stray-root-marker check (Check 2c, T-1747 / G-069)
# warned on /.framework.yaml but not /.tasks/, although every project-root
# resolver accepts either marker. A stray /.tasks/ (an escaped T-9999 test
# fixture) made reanchor_project_root return / for 37 days with doctor green.
#
# FW_DOCTOR_STRAY_ROOT points the check at a temp dir so the real / is never
# touched.

load ../test_helper

setup() {
    STRAY="$(mktemp -d)"
    export STRAY
    export NO_COLOR=1
}

teardown() {
    [ -d "${STRAY:-}" ] && rm -rf "$STRAY"
}

run_doctor() {
    cd "$FRAMEWORK_ROOT"
    run env FW_DOCTOR_STRAY_ROOT="$STRAY" "$FRAMEWORK_ROOT/bin/fw" doctor --quick
    # doctor colours its verdicts unconditionally; strip ANSI before matching
    output=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g')
}

@test "a stray .tasks/ at the root is reported" {
    mkdir -p "$STRAY/.tasks/active"
    run_doctor
    echo "$output" | grep -qF "WARN  [host] Stray $STRAY/.tasks/ at filesystem root"
}

@test "a stray .framework.yaml at the root is still reported (T-1747 leg)" {
    echo "version: 1.5.0" > "$STRAY/.framework.yaml"
    run_doctor
    echo "$output" | grep -qF "WARN  [host] Stray $STRAY/.framework.yaml at filesystem root"
}

@test "no marker at the root: no stray-marker warning (mutation control)" {
    run_doctor
    ! echo "$output" | grep -q "Stray $STRAY/" || false
}
