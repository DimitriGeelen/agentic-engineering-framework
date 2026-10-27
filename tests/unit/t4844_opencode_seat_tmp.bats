#!/usr/bin/env bats
# T-4844: the opencode review seat may use SEAT_TMP (one signed allowance, nothing else outside the
# export), and a seat that exits 0 with no verdict is recorded and reported as no-verdict.
# Behaviour lives in the pytest file (stub seats through the real run.sh, plus the real installed
# opencode's plan-agent rules); this wrapper runs it under the bats gate.

@test "opencode seat: SEAT_TMP allowed, outside refused; no-verdict is named" {
    cd "$BATS_TEST_DIRNAME/../.."
    run timeout 600 python3 -m pytest tests/unit/t4844_opencode_seat_tmp_test.py -q -p no:cacheprovider -rs
    echo "$output" | tail -15
    [ "$status" -eq 0 ]
    [[ "$output" == *"15 passed"* ]]
    [[ "$output" != *"skipped"* ]]
}
