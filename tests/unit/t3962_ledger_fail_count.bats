#!/usr/bin/env bats
# T-3962 — the reviewer-verdict-ledger FAIL names the total and marks a truncated sample.
# ring20 (2026-10-06) read "3 bad rows" from the pre-push line, which showed `head -3` of the
# failing rows; the full audit had 10. The block is lifted from audit.sh and run with a stub.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BLOCK="$(awk '/# T-3962: name the total/{p=1} p{print} p&&/Inspect: python3 lib\/verdict_ledger.py audit/{exit}' \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh")"
}

_run_block() {   # $1 = number of FAIL lines in the audit output
    local n="$1"
    bash -c '
        fail() { echo "TITLE=$1"; echo "EVIDENCE=$2"; }
        _vl_out=$(for i in $(seq 1 '"$n"'); do echo "FAIL row-$i: introduced by other"; done; echo "summary: x")
        '"$BLOCK"'
    '
}

@test "T-3962: the block was found in audit.sh" {
    [ -n "$BLOCK" ]
}

@test "T-3962: 5 failing rows -> the title names 5 and the evidence says first 3 of 5" {
    run _run_block 5
    [[ "$output" == *"TITLE=Reviewer-verdict ledger: 5 row(s) do not verify"* ]]
    [[ "$output" == *"EVIDENCE=first 3 of 5: FAIL row-1"* ]]
    [[ "$output" != *"row-4"* ]]
}

@test "T-3962/control: 2 failing rows -> no truncation marker, both shown" {
    run _run_block 2
    [[ "$output" == *"TITLE=Reviewer-verdict ledger: 2 row(s) do not verify"* ]]
    [[ "$output" == *"EVIDENCE=FAIL row-1"*"row-2"* ]]
    [[ "$output" != *"first 3 of"* ]]
}
