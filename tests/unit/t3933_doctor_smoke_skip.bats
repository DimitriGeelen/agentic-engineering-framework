#!/usr/bin/env bats
# T-3933 — FW_DOCTOR_SMOKE=0 keeps `fw doctor` from sweeping the live Watchtower.
#
# Six doctor test files ran full doctor ~38 times; every run's smoke step probed the
# LIVE server (one sweep measured 225 s under suite load), timing the files out at the
# 900 s cap and swamping Watchtower. Static legs: the guard sits before the probe, the
# suite runner exports it, and every doctor test file sets it.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# The smoke block, from its phase marker to the python call that sends the probes.
_smoke_block() {
    awk '/_doctor_phase "Watchtower smoke test"/{on=1} on{print} /web\/smoke_test.py/{if(on) exit}' \
        "$FRAMEWORK_ROOT/bin/fw"
}

@test "T-3933: the FW_DOCTOR_SMOKE=0 guard precedes the smoke probe" {
    block="$(_smoke_block)"
    [[ "$block" == *'"${FW_DOCTOR_SMOKE:-1}" = "0"'* ]]
    [[ "$block" == *"web/smoke_test.py"* ]]
    guard_line=$(printf '%s\n' "$block" | grep -n 'FW_DOCTOR_SMOKE:-1' | head -1 | cut -d: -f1)
    probe_line=$(printf '%s\n' "$block" | grep -n 'web/smoke_test.py' | tail -1 | cut -d: -f1)
    [ "$guard_line" -lt "$probe_line" ]
}

@test "T-3933: the guard branch prints SKIP and runs nothing else" {
    run bash -c '
        CYAN=""; NC=""
        FW_DOCTOR_SMOKE=0
        probed=0
        _doctor_quick_skip() { return 1; }
        if [ "${FW_DOCTOR_SMOKE:-1}" = "0" ]; then
            echo -e "  ${CYAN}SKIP${NC}  Watchtower smoke test (HTTP probes) (FW_DOCTOR_SMOKE=0)"
        elif _doctor_quick_skip "x"; then :; else probed=1; fi
        echo "probed=$probed"'
    [[ "$output" == *"SKIP  Watchtower smoke test (HTTP probes) (FW_DOCTOR_SMOKE=0)"* ]]
    [[ "$output" == *"probed=0"* ]]
}

@test "T-3933/control: without FW_DOCTOR_SMOKE the smoke block is still reached" {
    run bash -c '
        unset FW_DOCTOR_SMOKE
        probed=0
        _doctor_quick_skip() { return 1; }
        if [ "${FW_DOCTOR_SMOKE:-1}" = "0" ]; then :
        elif _doctor_quick_skip "x"; then :; else probed=1; fi
        echo "probed=$probed"'
    [[ "$output" == *"probed=1"* ]]
}

@test "T-3933: the unit-suite runner exports FW_DOCTOR_SMOKE=0" {
    grep -q '^export FW_DOCTOR_SMOKE=0' "$FRAMEWORK_ROOT/agents/audit/unit-suite.sh"
}

@test "T-3933: every unit test that runs full fw doctor sets FW_DOCTOR_SMOKE=0" {
    missing=""
    for f in "$FRAMEWORK_ROOT"/tests/unit/*.bats; do
        case "$f" in *t3933_doctor_smoke_skip.bats) continue ;; esac
        grep -qE 'run (bash )?"?\$?\{?[A-Za-z_]*\}?/?bin/fw"? doctor *$|run bin/fw doctor *$' "$f" || continue
        grep -q 'FW_DOCTOR_SMOKE=0' "$f" || missing="$missing $(basename "$f")"
    done
    [ -z "$missing" ] || { echo "full-doctor tests without FW_DOCTOR_SMOKE=0:$missing"; false; }
}
