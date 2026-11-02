#!/usr/bin/env bats
# T-5008: harness review seats run in their own PID namespace (a seat's `pkill -f` cannot reach a
# process outside it), fall back loudly where the host refuses it, and the watchdog still ends them.
# Behaviour lives in the pytest file (stub seats through the real run.sh); this wrapper runs it
# under the bats gate.

@test "review seats: own PID namespace, loud fallback, watchdog ends them, brief forbids pkill" {
    cd "$BATS_TEST_DIRNAME/../.."
    run timeout 600 python3 -m pytest tests/unit/t5008_seat_process_isolation_test.py -q -p no:cacheprovider -rs
    echo "$output" | tail -15
    [ "$status" -eq 0 ]
    [[ "$output" == *"6 passed"* ]]
    [[ "$output" != *"skipped"* ]]
}
