#!/usr/bin/env bats
# T-3875: two `set -euo pipefail` abort sites in do_doctor that T-3837 missed
# (reported by ring20-dashboard, 2026-10-05). The constructs are extracted from
# bin/fw itself and run under the shell options doctor runs with, so the test
# follows the real code rather than a copy of it.
#   (a) _at_out=$(python3 lib/audit_timing.py …) — a non-zero exit ended doctor
#   (b) slowest-phases `sort | head -3 | while` — head closed the pipe early,
#       sort took SIGPIPE (141) and pipefail+errexit ended doctor pre-summary.
# (b) is a race in the field (it needs sort to still be writing when head
# quits); a 30000-line phase log makes it deterministic.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FW="${BATS_TEST_DIRNAME}/../../bin/fw"
}

_phase_blocks() {   # every phase-log sort pipeline in bin/fw, verbatim, NUL-separated
    awk '/printf .%s. "\$_DOCTOR_PHASE_LOG" \| sort/ {p=1} p {print} p && !/\\$/ {p=0; printf "%c", 0}' "$FW"
}

@test "t3875: both phase-log pipelines are found in bin/fw (guards the extractor)" {
    [ "$(_phase_blocks | tr -cd '\0' | wc -c)" -eq 2 ]
    # no phase-log pipeline may close sort's output early again
    run bash -c "awk '/printf .%s. \"\\\$_DOCTOR_PHASE_LOG\" \\| sort/ {p=1} p {print} p && !/\\\\\$/ {p=0}' '$FW' | grep -E '\\| *head'"
    [ "$status" -ne 0 ]
}

@test "t3875 (b): every phase-log pipeline survives a large log under pipefail+errexit" {
    local block n=0
    while IFS= read -r -d '' block; do
        n=$((n + 1))
        run bash -c 'set -euo pipefail
            _DOCTOR_PHASE_LOG=$(for i in $(seq 1 30000); do echo "$i|phase-$i"; done)$'"'"'\n'"'"'
            '"$block"'
            echo SURVIVED'
        [ "$status" -eq 0 ]
        [[ "$output" == *"SURVIVED"* ]]
        # still the slowest first
        [[ "$output" == *"30000s  phase-30000"* ]]
    done < <(_phase_blocks)
    [ "$n" -eq 2 ]
}

@test "t3875 (b) CONTROL: the pre-fix head -3 construct does abort on the same input" {
    run bash -c 'set -euo pipefail
        L=$(for i in $(seq 1 30000); do echo "$i|phase-$i"; done)
        printf "%s" "$L" | sort -t"|" -k1,1nr | head -3 | while IFS="|" read -r s n; do :; done
        echo SURVIVED'
    [ "$status" -ne 0 ]
    [[ "$output" != *"SURVIVED"* ]]
}

@test "t3875 (a): the audit_timing capture carries a fallback" {
    run grep -E '_at_out=\$\(python3 "\$FRAMEWORK_ROOT/lib/audit_timing.py".*\) \|\| _at_out=""' "$FW"
    [ "$status" -eq 0 ]
    # and that shape survives a failing python under errexit (control: without it, it dies)
    run bash -c 'set -euo pipefail; f(){ local x; x=$(python3 -c "import sys; sys.exit(2)") || x=""; echo SURVIVED; }; f'
    [[ "$output" == *SURVIVED* ]]
    run bash -c 'set -euo pipefail; f(){ local x; x=$(python3 -c "import sys; sys.exit(2)"); echo SURVIVED; }; f'
    [[ "$output" != *SURVIVED* ]]
}
