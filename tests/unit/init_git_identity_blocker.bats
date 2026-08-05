#!/usr/bin/env bats
# T-2818 / OBS-170 — `fw init` must not sign off a project that cannot commit.
#
# A machine with no git identity makes `git commit` die RC=128 "Author identity
# unknown" *before any framework hook runs*, so onboarding task T-003 ("First
# governed commit") is impossible. This is not a hypothetical fresh-machine state:
# the host this was found on has no global identity at all — the framework repo
# works only because it carries a repo-local one, so every project `fw init`
# created there inherited the failure.
#
# The condition was already warned about three times (init line ~4 of ~120, the
# git-identity inheritance block, and `fw doctor`). What made it invisible is that
# every line printed AFTER the warning contradicted it: "Validation passed: 43/44",
# "Done! Governance is active.", "Next step: start your AI agent". The last thing
# read wins. So these tests pin the END of the output and the tally — the two
# places that were saying "ready" — not the existence of a warning.

bats_require_minimum_version 1.5.0

# Two full `fw init` runs, once per file rather than per test. Both are real inits
# against the real entry point: the claim is about what an operator sees at the end
# of `fw init`, and a unit-level stub of the closing block could not fail the way
# the shipped path failed.
setup_file() {
    FW="${BATS_TEST_DIRNAME}/../../bin/fw"
    export FW

    # Deliberately OUTSIDE the framework tree. `fw init` vendors from an ancestor
    # .agentic-framework when one exists (OBS-162), so a fixture nested under the
    # repo would exercise a different code path than a real consumer does.
    IDDIR="${BATS_FILE_TMPDIR:-/tmp}/t2818"
    export IDDIR
    rm -rf "$IDDIR"; mkdir -p "$IDDIR/home" "$IDDIR/missing" "$IDDIR/present"

    # State A: no identity resolvable. GIT_CONFIG_GLOBAL points at a file that does
    # not exist, which is how git represents "no global config" without touching the
    # host's real one.
    env HOME="$IDDIR/home" GIT_CONFIG_GLOBAL="$IDDIR/no-such-gitconfig" \
        "$FW" init "$IDDIR/missing" > "$IDDIR/missing.log" 2>&1 || true

    # State B: identity present, inherited from global. The negative control — without
    # it, a block that printed the blocker unconditionally would pass every assertion
    # about state A while making the message meaningless (L-530).
    printf '[user]\n\temail = someone@example.com\n\tname = Some One\n' > "$IDDIR/gitconfig"
    env HOME="$IDDIR/home" GIT_CONFIG_GLOBAL="$IDDIR/gitconfig" \
        "$FW" init "$IDDIR/present" > "$IDDIR/present.log" 2>&1 || true
}

@test "no identity: the blocker is stated in the closing block, not only at the top" {
    # The specific regression. The old output's last lines were "Done! Governance is
    # active." + "Next step: start your AI agent" — an unqualified all-clear.
    run bash -c 'sed "s/\x1b\[[0-9;]*m//g" "$IDDIR/missing.log" | tail -20'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Do this first"* ]]
    [[ "$output" == *"cannot commit yet"* ]]
}

@test "no identity: the closing block names T-003, the task that actually breaks" {
    run bash -c 'sed "s/\x1b\[[0-9;]*m//g" "$IDDIR/missing.log" | tail -20'
    [[ "$output" == *"T-003"* ]]
}

@test "no identity: the emitted command is copy-pasteable from any directory" {
    # T-609: a command handed to a human must carry its own cd. The earlier warning
    # at line ~4 prints a bare `git config`, which does nothing useful if the reader
    # has since changed directory.
    run bash -c 'sed "s/\x1b\[[0-9;]*m//g" "$IDDIR/missing.log" | grep -c "cd $IDDIR/missing && git config user.email"'
    [ "$output" -ge 1 ]
}

@test "no identity: running the emitted command verbatim makes a governed commit work" {
    # The end-to-end claim, and the only one that proves the message is CORRECT rather
    # than merely present. Extracts the string init actually printed instead of
    # retyping it here — a retyped copy would keep passing if the emitted one drifted.
    local cmd
    cmd=$(sed 's/\x1b\[[0-9;]*m//g' "$IDDIR/missing.log" \
          | grep -m1 "^ *cd $IDDIR/missing && git config user.email")
    [ -n "$cmd" ]

    run env HOME="$IDDIR/home" GIT_CONFIG_GLOBAL="$IDDIR/no-such-gitconfig" bash -c "$cmd"
    [ "$status" -eq 0 ]

    # Before: RC=128 "Author identity unknown". After: a real commit through the
    # commit-msg hook, which is what onboarding T-003 asks the operator to do.
    run env HOME="$IDDIR/home" GIT_CONFIG_GLOBAL="$IDDIR/no-such-gitconfig" bash -c \
        "cd '$IDDIR/missing' && echo hi > t2818.txt && git add t2818.txt && git commit -m 'T-003: first governed commit'"
    [ "$status" -eq 0 ]
}

@test "identity present: no blocker is shown" {
    run bash -c 'sed "s/\x1b\[[0-9;]*m//g" "$IDDIR/present.log"'
    [[ "$output" != *"Do this first"* ]]
    [[ "$output" != *"cannot commit yet"* ]]
    [[ "$output" == *"Governance is active."* ]]
}

@test "the validation tally counts the identity check in both states" {
    # The denominator was the other surface saying "ready": 44 checks, none of them
    # about the one condition blocking the next step.
    run bash -c 'sed "s/\x1b\[[0-9;]*m//g" "$IDDIR/missing.log" | grep -c "func-identity"'
    [ "$output" -ge 1 ]
    run bash -c 'sed "s/\x1b\[[0-9;]*m//g" "$IDDIR/present.log" | grep -c "func-identity"'
    [ "$output" -ge 1 ]
}

@test "the identity check does not fail validation — it is host state, not project state" {
    # Re-running after `git config` flips it green with no re-init, and a hard failure
    # would redden every CI job that legitimately runs without an identity, training
    # people to ignore validation output — the exact failure mode being fixed here.
    run bash -c 'sed "s/\x1b\[[0-9;]*m//g" "$IDDIR/missing.log" | grep "Validation"'
    [[ "$output" == *"Validation passed"* ]]
}
