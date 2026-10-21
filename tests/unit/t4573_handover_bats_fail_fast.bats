#!/usr/bin/env bats
# T-4573: tests/unit/handover.bats must fail fast, not hang, when handover.sh
# regresses. Each _handover call is bounded at HANDOVER_TEST_TIMEOUT, but eight
# tests call it, so without a file-level stop a slow handover.sh costs 8 x 120 s
# and overruns the runner's 900 s per-file cap. Drives the real handover.bats
# against a stub that answers --help and sleeps otherwise.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "handover.bats stops after the first handover.sh timeout" {
    local stub="$BATS_TEST_TMPDIR/slow-handover.sh"
    printf '#!/bin/sh\ncase "$1" in -h|--help) echo "handover --commit --checkpoint"; exit 0;; esac\nsleep 30\n' > "$stub"
    chmod +x "$stub"

    run env HANDOVER_TEST_SCRIPT="$stub" HANDOVER_TEST_TIMEOUT=1 \
        timeout 120 bats --tap "$FRAMEWORK_ROOT/tests/unit/handover.bats"
    [ "$status" -ne 124 ]
    echo "$output"
    # Exactly one generation test fails on the timeout; the rest skip with the reason.
    [ "$(grep -c '^not ok' <<<"$output")" -eq 1 ]
    [ "$(grep -c '# skip handover.sh already exceeded' <<<"$output")" -eq 7 ]
    # The --help tests do not go through _handover and still pass.
    grep -q '^ok 1 handover --help shows usage' <<<"$output"
}
