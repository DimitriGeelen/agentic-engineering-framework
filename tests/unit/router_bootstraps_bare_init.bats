#!/usr/bin/env bats
# T-2814 — `fw init` in a bare directory bootstraps instead of refusing.
#
# Origin: the operator's onboarding prompt is a two-step shape — install PATH
# tooling, then `fw init` in a new directory. After T-2809 moved framework bytes
# into the project, that second step became a hard 127: init is framework code and
# there is no framework. The T-2810 refusal told the operator to run install.sh,
# which does exactly what they had just asked for. Operator, correctly: "why do you
# not change that?"
#
# The safety of this feature is entirely in its SCOPE, so that is what these tests
# are mostly about:
#   - `init` only (test 2) — a fetch on `fw status` would be indefensible
#   - only when no framework was found at all, which today is always a hard 127
#   - opt-out honoured (test 3)
#   - any fetch failure lands on the refusal, not a raw curl error (test 4)
#
# FW_INSTALL_URL points at a local stub, so nothing here touches the network.

bats_require_minimum_version 1.5.0

setup() {
    ROUTER="$BATS_TEST_DIRNAME/../../bin/fw-router"
    FAKE_HOME="$BATS_TEST_TMPDIR/home"          # no global install
    BARE="$BATS_TEST_TMPDIR/bare"
    mkdir -p "$FAKE_HOME" "$BARE"

    # Stand-in for install.sh. Records how it was invoked so we can assert the
    # target directory and forwarded flags without running a real install.
    STUB="$BATS_TEST_TMPDIR/install-stub.sh"
    RECORD="$BATS_TEST_TMPDIR/invocation"
    cat > "$STUB" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "$RECORD"
echo "stub-installer-ran"
EOF
    chmod +x "$STUB"
}

run_router_in() {
    local dir="$1"; shift
    run env HOME="$FAKE_HOME" FW_GLOBAL_ROOT="$FAKE_HOME/.agentic-framework" \
        FW_INSTALL_URL="file://$STUB" "$@" \
        bash -c "cd '$dir' && '$ROUTER' \$FW_TEST_ARGS"
}

@test "bare init fetches the installer and targets this directory" {
    FW_TEST_ARGS="init" run_router_in "$BARE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"stub-installer-ran"* ]] || fail "installer was not run: $output"
    grep -qx "$BARE" "$RECORD" || fail "installer not pointed at the cwd; got: $(cat "$RECORD")"
}

@test "flags after init are forwarded, not dropped" {
    # A bootstrap that silently loses --provider is worse than a refusal: the
    # wrong answer gets persisted into .framework.yaml instead of erroring.
    FW_TEST_ARGS="init --provider claude" run_router_in "$BARE"
    [ "$status" -eq 0 ]
    grep -qx -- "--provider" "$RECORD" || fail "flag dropped; got: $(cat "$RECORD")"
    grep -qx -- "claude" "$RECORD" || fail "flag value dropped; got: $(cat "$RECORD")"
}

@test "only init bootstraps — any other verb still refuses" {
    # The dangerous version of this feature is the one where `fw status` in a
    # random directory starts downloading things.
    FW_TEST_ARGS="status" run_router_in "$BARE"
    [ "$status" -eq 127 ]
    [[ "$output" == *"no framework found"* ]]
    [ ! -f "$RECORD" ] || fail "installer ran for a non-init verb: $(cat "$RECORD")"
}

@test "FW_NO_BOOTSTRAP=1 restores the refusal" {
    FW_TEST_ARGS="init" run_router_in "$BARE" FW_NO_BOOTSTRAP=1
    [ "$status" -eq 127 ]
    [[ "$output" == *"no framework found"* ]]
    [ ! -f "$RECORD" ] || fail "installer ran despite FW_NO_BOOTSTRAP=1"
}

@test "a failed fetch falls through to the refusal, not a raw curl error" {
    # The operator must land on the copy-pasteable one-step command (T-2810)
    # rather than on curl's exit status.
    FW_TEST_ARGS="init" run env HOME="$FAKE_HOME" \
        FW_GLOBAL_ROOT="$FAKE_HOME/.agentic-framework" \
        FW_INSTALL_URL="file://$BATS_TEST_TMPDIR/does-not-exist.sh" \
        bash -c "cd '$BARE' && '$ROUTER' init"
    [ "$status" -eq 127 ]
    [[ "$output" == *"no framework found"* ]]
    [[ "$output" == *"bash -s --"* ]] || fail "refusal lost its one-step command"
}

@test "the bootstrap announcement is on stderr, never stdout" {
    # T-2769/T-2771 stdout-purity contract: diagnostics never contaminate stdout.
    env HOME="$FAKE_HOME" FW_GLOBAL_ROOT="$FAKE_HOME/.agentic-framework" \
        FW_INSTALL_URL="file://$STUB" \
        bash -c "cd '$BARE' && '$ROUTER' init" \
        >"$BATS_TEST_TMPDIR/out" 2>"$BATS_TEST_TMPDIR/err"
    grep -q "bootstrapping into" "$BATS_TEST_TMPDIR/err"
    if grep -q "bootstrapping into" "$BATS_TEST_TMPDIR/out"; then false; fi
    # Non-vacuity: the installer's own output DID reach stdout, so the assertion
    # above is about routing of the announcement, not about an empty stream.
    grep -q "stub-installer-ran" "$BATS_TEST_TMPDIR/out"
}
