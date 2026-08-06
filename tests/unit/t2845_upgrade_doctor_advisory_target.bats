#!/usr/bin/env bats
# T-2845: the post-upgrade health check must exercise the CONSUMER's fw.
#
# During `fw upgrade`, FRAMEWORK_ROOT is a temporary upstream clone
# (/tmp/fw-upstream-XXXXXX/fw). The advisory used it, so it health-checked the
# upstream and merely pointed it at the consumer's directory — the vendored copy
# the operator will actually run was never exercised.
#
# These tests work by making the two candidate fw binaries distinguishable: each
# stub prints a unique marker. The assertion is about WHICH ONE RAN, which is the
# whole content of the bug. Asserting on doctor's output instead would pass
# against either binary.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."

    # Stand in for the temporary upstream clone.
    # The stubs echo the FRAMEWORK_ROOT they were handed as well as their own
    # identity. Both channels matter: `fw` honours an inherited FRAMEWORK_ROOT
    # over its own location, so running the consumer's binary with the clone's
    # FRAMEWORK_ROOT still exercises the clone. The first version of this fix
    # switched only the binary, these tests passed, and live behaviour was
    # completely unchanged — which is why the env is asserted here too.
    UPSTREAM="$BATS_TEST_TMPDIR/upstream/fw"
    mkdir -p "$UPSTREAM/bin"
    printf '#!/usr/bin/env bash\necho UPSTREAM_FW_RAN\necho "FR=$FRAMEWORK_ROOT"\n' > "$UPSTREAM/bin/fw"
    chmod +x "$UPSTREAM/bin/fw"

    # Stand in for the consumer project.
    CONSUMER="$BATS_TEST_TMPDIR/consumer"
    mkdir -p "$CONSUMER"

    FRAMEWORK_ROOT="$UPSTREAM"
    export FRAMEWORK_ROOT
    BOLD=""; NC=""; YELLOW=""; GREEN=""
    source "$FW_ROOT/lib/upgrade.sh"
}

_give_consumer_vendored_fw() {
    mkdir -p "$CONSUMER/.agentic-framework/bin"
    printf '#!/usr/bin/env bash\necho CONSUMER_FW_RAN\necho "FR=$FRAMEWORK_ROOT"\n' \
        > "$CONSUMER/.agentic-framework/bin/fw"
    chmod +x "$CONSUMER/.agentic-framework/bin/fw"
}

@test "vendored consumer: advisory runs the consumer's fw, not the upstream clone's" {
    _give_consumer_vendored_fw
    run _t2094_emit_doctor_advisory "$CONSUMER"
    [[ "$output" == *"CONSUMER_FW_RAN"* ]]
    [[ "$output" != *"UPSTREAM_FW_RAN"* ]]
}

@test "vendored consumer: FRAMEWORK_ROOT moves with the binary" {
    # The load-bearing assertion. Switching only the binary leaves the consumer's
    # fw resolving against the temp clone, and the observable behaviour is
    # identical to no fix at all.
    _give_consumer_vendored_fw
    run _t2094_emit_doctor_advisory "$CONSUMER"
    [[ "$output" == *"FR=$CONSUMER/.agentic-framework"* ]]
    [[ "$output" != *"FR=$UPSTREAM"* ]]
}

@test "no vendored copy: advisory falls back to FRAMEWORK_ROOT's fw and root" {
    # Shared-tooling / global consumers must keep working.
    run _t2094_emit_doctor_advisory "$CONSUMER"
    [[ "$output" == *"UPSTREAM_FW_RAN"* ]]
    [[ "$output" == *"FR=$UPSTREAM"* ]]
}

@test "non-executable vendored fw falls back rather than failing" {
    mkdir -p "$CONSUMER/.agentic-framework/bin"
    printf '#!/usr/bin/env bash\necho CONSUMER_FW_RAN\n' > "$CONSUMER/.agentic-framework/bin/fw"
    chmod -x "$CONSUMER/.agentic-framework/bin/fw"
    run _t2094_emit_doctor_advisory "$CONSUMER"
    [[ "$output" == *"UPSTREAM_FW_RAN"* ]]
}

@test "advisory stays non-blocking when the consumer's fw exits non-zero" {
    # F10 is advisory by spec: a failing doctor must not fail the upgrade.
    mkdir -p "$CONSUMER/.agentic-framework/bin"
    printf '#!/usr/bin/env bash\necho CONSUMER_FW_RAN\nexit 2\n' > "$CONSUMER/.agentic-framework/bin/fw"
    chmod +x "$CONSUMER/.agentic-framework/bin/fw"
    run _t2094_emit_doctor_advisory "$CONSUMER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONSUMER_FW_RAN"* ]]
    [[ "$output" == *"doctor exited 2"* ]]
}
