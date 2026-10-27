#!/usr/bin/env bats
# T-4835: review seats run with PYTHONDONTWRITEBYTECODE=1 so a Python corroboration run does not
# void the seat via the T-3986 export fingerprint. Behaviour lives in the pytest file (stub seats
# through the real run.sh); this wrapper runs it under the bats gate.

@test "review seat python run leaves the export fingerprint unchanged; a real edit still voids" {
    cd "$BATS_TEST_DIRNAME/../.."
    run timeout 600 python3 -m pytest tests/unit/t4835_review_seat_pycache_test.py -q -p no:cacheprovider
    echo "$output" | tail -15
    [ "$status" -eq 0 ]
    [[ "$output" == *"5 passed"* ]]
}
