#!/usr/bin/env bats
#
# T-3138 — pin the bash mechanism that made 106 assertions in this suite inert.
#
# Bash's `set -e` documentation says the shell does not exit "if the command's
# return value is being inverted with `!`". Bats runs each `@test` body under
# `set -e` and takes the body's exit status as the verdict. So a `!`-inverted
# line that is NOT the last statement of its body is checked by nothing: errexit
# is exempted, and the body's status comes from a later line.
#
# This file does not assert that claim in prose — it runs bats on a fixture and
# reads the verdicts back. Anyone meeting `tools/bats-dead-negation-lint.py` or
# the `if X; then false; fi` conversions later can re-derive why they exist by
# running this file, without trusting T-3138's write-up.
#
# The cases below were measured, not assumed, before the 106-site sweep chose
# its replacement form. Case E is recorded specifically because it is the
# tempting one-line fix and it does work — the sweep preferred D anyway, for
# legibility, and the record of that choice belongs with the measurement.

setup() {
    FIX="$BATS_TEST_TMPDIR/fixture.bats"
    export FIX
}

# _outcome <test-number> — "ok" or "not ok" for one test of the fixture.
# The fixture is EXPECTED to contain failures, so bats' own exit code is not the
# signal here; the per-test TAP lines are. `|| true` keeps that non-zero exit
# from aborting this body before the verdicts are read.
_outcome() {
    local n="$1" out
    out="$(bats "$FIX" 2>&1 || true)"
    if printf '%s\n' "$out" | grep -qE "^not ok $n "; then
        printf 'not ok\n'
    elif printf '%s\n' "$out" | grep -qE "^ok $n "; then
        printf 'ok\n'
    else
        printf 'MISSING\n'
    fi
}

_fixture() {
    # BATSTEST, not @test. Bats rewrites every line starting with `@test` when it
    # preprocesses THIS file — including lines inside a quoted heredoc, which it
    # cannot see the quoting of. A fixture written with a literal `@test` reaches
    # disk already transformed into bats' internal `bats_test_function` form, so
    # the file under test is not the file that was written. Discovered here by
    # dumping $FIX after every lint assertion inverted (T-3138).
    sed 's/^BATSTEST /@test /' > "$FIX"
}

@test "T-3138/AC1: a NON-FINAL bang-negation cannot fail its test" {
    # The defect. `! true` is a failed assertion by intent — the test passes.
    _fixture <<'EOF'
BATSTEST "subject" {
    ! true
    true
}
EOF
    [ "$(_outcome 1)" = "ok" ]
}

@test "T-3138/AC1: a FINAL bang-negation DOES fail its test" {
    # Same statement, last position. Bats takes the body's status from it, so
    # errexit's exemption is irrelevant. These are why the lint counts final-
    # position negations separately instead of flagging every `!` it sees.
    _fixture <<'EOF'
BATSTEST "subject" {
    true
    ! true
}
EOF
    [ "$(_outcome 1)" = "not ok" ]
}

@test "T-3138/AC1: a NON-FINAL [[ != ]] DOES fail its test" {
    # The R1/R2 conversion. The negation moves inside a single command, so there
    # is no `!`-inverted return value for errexit to exempt.
    _fixture <<'EOF'
BATSTEST "subject" {
    [[ a != a ]]
    true
}
EOF
    [ "$(_outcome 1)" = "not ok" ]
}

@test "T-3138/AC1: a NON-FINAL if-then-false DOES fail its test" {
    # The R3 conversion, used at 83 of the 106 sites. errexit is suppressed only
    # in an `if` CONDITION; the branch body is checked normally, so the `false`
    # aborts. This is what makes R3 safe for shapes (pipelines, env prefixes,
    # redirects) that do not fit inside `[[ ]]`.
    _fixture <<'EOF'
BATSTEST "subject" {
    if true; then false; fi
    true
}
EOF
    [ "$(_outcome 1)" = "not ok" ]
}

@test "T-3138/AC1: the tempting one-liner ! cmd || false also fires" {
    # Recorded because it is the smallest possible edit and it is NOT broken —
    # the sweep rejected it on legibility, not correctness. Without this case
    # the next reader has to re-run the experiment to find that out.
    _fixture <<'EOF'
BATSTEST "subject" {
    ! true || false
    true
}
EOF
    [ "$(_outcome 1)" = "not ok" ]
}

@test "T-3138/AC1: the pipeline shape — the commonest dead form here — is dead" {
    # 49 of the 106 were `! echo "$output" | grep -q ...`. The `!` applies to the
    # whole pipeline, so the exemption covers it just as it covers a bare command.
    _fixture <<'EOF'
BATSTEST "subject" {
    ! echo hi | grep -q hi
    true
}
EOF
    [ "$(_outcome 1)" = "ok" ]
}

@test "T-3138/AC1 [regression guard]: the fixture harness reports real verdicts" {
    # If _outcome silently returned MISSING for everything, every assertion above
    # comparing against "not ok" would still be wrong-but-quiet in one direction.
    # This pins that the harness distinguishes all three states.
    _fixture <<'EOF'
BATSTEST "passes" {
    true
}
EOF
    [ "$(_outcome 1)" = "ok" ]
    [ "$(_outcome 2)" = "MISSING" ]
}
