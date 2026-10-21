#!/usr/bin/env bats
# T-3778: doctor-calling bats files must not pay a whole `fw doctor` per test.
#
# One doctor run costs ~50 s on a quiet host and 270-600 s under the unit-suite
# pool (measured at load 170: full 10m09s, --quick 4m31s). Files that ran it once
# per test crossed the 900 s per-file cap: doctor_designer_pin_drift.bats (5 runs,
# 900 s), t2243_doctor_self_vendor_templates.bats (4 runs, 848 s) and
# test_doctor_scope_tags.bats (4 runs, 757 s) on the 2026-10-21 nightly. The two
# drift checks now live in lib/doctor-drift.sh so the tests call them directly;
# scope_tags shares one run via setup_file.
#
# This file pins the budget (at most ONE doctor invocation per file) and the
# extraction (no inline copy of either check left in bin/fw).

load ../test_helper

# Count non-comment lines that invoke doctor via bin/fw or $FW_BIN.
_doctor_runs() {
    grep -vE '^[[:space:]]*#' "$FRAMEWORK_ROOT/tests/unit/$1" \
        | grep -cE '(bin/fw|FW_BIN)"?[[:space:]]+doctor' || true
}

@test "T-3778: each previously over-cap doctor file runs doctor at most once" {
    local f n
    for f in doctor_designer_pin_drift.bats t2243_doctor_self_vendor_templates.bats \
             test_doctor_scope_tags.bats; do
        n=$(_doctor_runs "$f")
        echo "$f: $n doctor invocation(s)"
        [ "$n" -le 1 ]
    done
}

@test "T-3778: bin/fw sources lib/doctor-drift.sh and keeps no inline copy of either check" {
    run grep -c 'doctor_check_designer_pin$' "$FRAMEWORK_ROOT/bin/fw"
    [ "$output" -eq 1 ]
    run grep -c 'doctor_check_vendored_drift "$FRAMEWORK_ROOT"' "$FRAMEWORK_ROOT/bin/fw"
    [ "$output" -eq 1 ]
    # The inline blocks' own variables must be gone, or the two copies can drift.
    run grep -cE '_dz_want|_vdrift_libs' "$FRAMEWORK_ROOT/bin/fw"
    [ "$output" -eq 0 ]
}

@test "T-3778: lib/doctor-drift.sh parses and defines both checks" {
    run bash -n "$FRAMEWORK_ROOT/lib/doctor-drift.sh"
    [ "$status" -eq 0 ]
    run bash -c 'source "$1/lib/doctor-drift.sh"; declare -F doctor_check_designer_pin doctor_check_vendored_drift' \
        _ "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | wc -l)" -eq 2 ]
}
