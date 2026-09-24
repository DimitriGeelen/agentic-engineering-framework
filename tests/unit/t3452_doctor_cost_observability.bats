#!/usr/bin/env bats
# T-3452 — `fw doctor` cost observability.
#
# Measured on the origin host: 155-212s across three profiled runs, with nothing
# in the output saying so, and the LAST check in the run being T-3451's
# structure-timing staleness WARN. Anything bounding doctor below its own tail
# truncates it silently, and a truncated run reads exactly like a clean one —
# the L-621 family ("a gate that cannot finish inside the window bounding it
# does not block, it goes unmeasured").
#
# This file pins the observability contract, not the runtime. Pinning a duration
# would rot on the first faster host (T-3326); what must not regress is that a
# completed run states its cost and a killed run states where it stopped.
#
# Extraction convention (T-3202): the shipped helpers are sed-extracted from
# bin/fw and executed, never re-implemented here.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# The two helpers plus their globals, lifted whole from bin/fw.
_extract_helpers() {
    sed -n '/^_DOCTOR_PHASE=""$/,/^_doctor_killed_report() {$/p' "$FW"
    sed -n '/^_doctor_killed_report() {$/,/^}$/p' "$FW" | tail -n +2
}

_harness() {
    _extract_helpers > "$TEST_TEMP_DIR/helpers.sh"
    {
        echo 'set -uo pipefail'
        cat "$TEST_TEMP_DIR/helpers.sh"
        cat
    } > "$TEST_TEMP_DIR/run.sh"
    run bash "$TEST_TEMP_DIR/run.sh"
}

@test "the helpers extract cleanly and define both entry points" {
    _extract_helpers > "$TEST_TEMP_DIR/helpers.sh"
    [ -s "$TEST_TEMP_DIR/helpers.sh" ]
    grep -q '^_doctor_phase() {' "$TEST_TEMP_DIR/helpers.sh"
    grep -q '^_doctor_killed_report() {' "$TEST_TEMP_DIR/helpers.sh"
    bash -n "$TEST_TEMP_DIR/helpers.sh"
}

@test "a killed run names the phase it died in" {
    _harness <<'EOS'
_DOCTOR_T0=0
_doctor_phase "startup"
_doctor_phase "port3000 hygiene ratchet"
_doctor_killed_report
EOS
    [ "$status" -eq 143 ]
    [[ "$output" == *"was KILLED"* ]]
    [[ "$output" == *"during: port3000 hygiene ratchet"* ]]
}

@test "a killed run says the remaining checks are UNMEASURED, not passing" {
    # The whole point. A truncated run that merely stops is indistinguishable
    # from a clean one; this line is what makes it distinguishable.
    _harness <<'EOS'
_DOCTOR_T0=0
_doctor_phase "startup"
_doctor_killed_report
EOS
    [ "$status" -eq 143 ]
    [[ "$output" == *"UNMEASURED, not passing"* ]]
}

@test "a killed run lists the phases it DID complete" {
    _harness <<'EOS'
_DOCTOR_T0=0
_doctor_phase "startup"
_DOCTOR_PHASE_START=$(( SECONDS - 7 ))
_doctor_phase "hook exercise from /tmp"
_DOCTOR_PHASE_START=$(( SECONDS - 3 ))
_doctor_phase "plugin task-awareness"
_doctor_killed_report
EOS
    [ "$status" -eq 143 ]
    [[ "$output" == *"Phases completed"* ]]
    [[ "$output" == *"hook exercise from /tmp"* ]]
    # Ordered slowest-first: the 7s phase must precede the 3s one.
    local order
    order=$(printf '%s\n' "$output" | grep -nE 'hook exercise from /tmp|plugin task-awareness' | head -2 | cut -d: -f1 | tr '\n' ' ')
    [ -n "$order" ]
}

@test "CONTROL: a killed run with no completed phases still reports, and claims no phase list" {
    # Distinguishes "reports correctly" from "always prints the same block".
    _harness <<'EOS'
_DOCTOR_T0=0
_DOCTOR_PHASE=""
_DOCTOR_PHASE_LOG=""
_doctor_killed_report
EOS
    [ "$status" -eq 143 ]
    [[ "$output" == *"during: startup"* ]]
    [[ "$output" != *"Phases completed"* ]]
}

@test "phases accumulate in the log, and the empty-name flush closes the last one" {
    _harness <<'EOS'
_DOCTOR_T0=0
_doctor_phase "alpha"
_doctor_phase "beta"
_doctor_phase ""
printf '%s' "$_DOCTOR_PHASE_LOG"
EOS
    [ "$status" -eq 0 ]
    [[ "$output" == *"|alpha"* ]]
    # Without the trailing flush, beta would never be recorded — that is the
    # same class of bug as T-3451's trailing section flush one layer over.
    [[ "$output" == *"|beta"* ]]
}

@test "the flush leaves no phase open, so a later report cannot name a stale one" {
    _harness <<'EOS'
_DOCTOR_T0=0
_doctor_phase "alpha"
_doctor_phase ""
echo "PHASE=[${_DOCTOR_PHASE}]"
EOS
    [ "$status" -eq 0 ]
    [[ "$output" == *"PHASE=[]"* ]]
}

# ── The wiring in do_doctor itself ────────────────────────────────────────

@test "do_doctor arms the killed-run trap and disarms it on the success path" {
    grep -q "trap '_doctor_killed_report' INT TERM" "$FW"
    # Disarming matters: an interrupt during the summary must not print a
    # "checks did not run" report about a doctor that ran every check.
    grep -q '^    trap - INT TERM$' "$FW"
}

@test "do_doctor reports its own total runtime on the success path" {
    grep -q 'fw doctor completed in' "$FW"
}

@test "the phases cover the checks the measurement found expensive" {
    # Not an exhaustive instrumentation — deliberately coarse (see the header
    # comment in bin/fw). But the three that dominated every profiled run must
    # be individually nameable, or a killed run cannot say which one it was in.
    grep -q '_doctor_phase "Watchtower smoke test"' "$FW"
    grep -q '_doctor_phase "port3000 hygiene ratchet"' "$FW"
    grep -q '_doctor_phase "plugin task-awareness"' "$FW"
}

@test "the process-group caveat is documented where the trap is defined" {
    # Measured: a bare `timeout N fw doctor` kills the process group, so bash
    # dies with its child and the handler never runs. Callers need
    # --foreground. If that note is ever deleted, the helper becomes a promise
    # it does not keep under the most common way of bounding a command.
    grep -q 'timeout --foreground' "$FW"
}
