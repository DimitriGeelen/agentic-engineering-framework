#!/usr/bin/env bats
# T-3119 — `fw doctor` designer pin CURRENCY check.
#
# The pre-existing designer check (T-2524, doctor_designer_pin_drift.bats) measures
# EXPOSURE: does the vendored build match what we pinned. It says nothing about
# whether the pin is still the newest thing the origin publishes. That blind spot
# let designer-v0.9.0 → v0.11.0 sit unconsumed for three releases with every
# instrument green. This suite pins the CURRENCY half.
#
# Surface under test: bin/fw doctor, designer-pin-currency block.
# States:
#   pin behind newest origin tag   → WARN, names BOTH versions + the tag  — t1
#   pin == newest origin tag       → OK, no WARN                          — t2
#   origin unreachable             → distinct SKIP-shaped state, NOT "current" — t3
#
# REAL REMOTE, not a mock: each test inits a bare git repo in $BATS_TEST_TMPDIR and
# pushes annotated designer-v* tags to it, then points a temp pin at it. Mocking
# `git ls-remote` would test the parser and nothing else — the tag shapes
# (refs/tags/X and the ^{} peeled line) are exactly what the parser has to survive.
#
# HERMETIC (T-2547): FW_DESIGNER_PIN_FILE points doctor at a TEMP COPY of the pin.
# The live tracked policy/designer-pin.yaml is never written, so an interrupted run
# leaves the working tree clean.
#
# t1 deliberately pins 0.8.0 against tags {0.8.0, 0.10.0, 0.11.0}: a LEXICAL compare
# ranks "0.8.0" highest of that set and reports the pin current, so t1 is also the
# semantic-versus-lexical mutation guard. Requirement 3 has no separate test because
# this one already kills that mutant.

load ../test_helper

setup() {
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"

    ORIGIN="$BATS_TEST_TMPDIR/designer-origin.git"
    WORK="$BATS_TEST_TMPDIR/designer-work"
    git init -q --bare "$ORIGIN"
    git init -q "$WORK"
    (
        cd "$WORK"
        git config user.email t3119@test.local
        git config user.name "T-3119 fixture"
        echo "designer build fixture" > build.txt
        git add build.txt
        git commit -qm "T-3119: fixture commit"
        for v in 0.8.0 0.10.0 0.11.0; do
            git tag -a "designer-v$v" -m "release $v"
        done
        git remote add origin "$ORIGIN"
        git push -q origin HEAD --tags
    )

    PIN_TMP="$BATS_TEST_TMPDIR/designer-pin.yaml"
    export FW_DESIGNER_PIN_FILE="$PIN_TMP"
    # Never inherit an operator opt-out — that would make every case pass vacuously.
    export FW_SKIP_DESIGNER_CURRENCY=0
}

teardown() {
    unset FW_DESIGNER_PIN_FILE FW_SKIP_DESIGNER_CURRENCY
}

# _pin <version> <origin> — write the temp pin: a verbatim copy of the live pin with
# only version:/source_origin: overridden, so the sibling drift check still behaves
# normally and this suite tests one variable at a time.
_pin() {
    python3 - "$FRAMEWORK_ROOT/policy/designer-pin.yaml" "$PIN_TMP" "$1" "$2" <<'PY'
import sys, yaml
src, dst, version, origin = sys.argv[1:5]
d = yaml.safe_load(open(src))
d['version'] = version
d['source_origin'] = origin
yaml.safe_dump(d, open(dst, 'w'), sort_keys=False)
PY
}

# _line <substring> — the ONE doctor line containing <substring>, ANSI stripped.
# Line-scoped on purpose: `[[ "$output" == *WARN*designer* ]]` passes against a SKIP,
# because a ~40-line doctor run has almost always already printed some other WARN.
_line() {
    printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -- "$1" | head -1
}

@test "t1: pin behind newest origin tag → WARN naming both versions and the tag" {
    _pin 0.8.0 "$ORIGIN"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor

    local vline
    vline=$(_line "designer pin is behind its origin")
    [ -n "$vline" ]
    [[ "$vline" == *"WARN"* ]]
    [[ "$vline" != *"SKIP"* ]]
    # Both versions on the verdict line — the operator must not have to go look up
    # what they are currently pinned to in order to read the finding.
    [[ "$vline" == *"0.8.0"* ]]
    [[ "$vline" == *"0.11.0"* ]]
    # 0.11.0, not 0.8.0: sort -V, not a string compare (see header note).
    [[ "$vline" != *"newest released 0.8.0"* ]]
    # The tag is the actionable handle for `fw designer sync --from-tag`.
    [[ "$output" == *"designer-v0.11.0"* ]]
    [[ "$output" == *"fw designer sync --from-tag"* ]]
    [[ "$output" != *"designer pin current with origin"* ]]
}

@test "t2: pin == newest origin tag → OK, no currency WARN" {
    _pin 0.11.0 "$ORIGIN"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor

    local vline
    vline=$(_line "designer pin current with origin")
    [ -n "$vline" ]
    [[ "$vline" == *"OK"* ]]
    [[ "$vline" != *"WARN"* ]]
    [[ "$vline" == *"0.11.0"* ]]
    [[ "$output" != *"designer pin is behind its origin"* ]]
    [[ "$output" != *"could not reach origin"* ]]
}

@test "t3: unreachable origin → distinct non-failing state, never reads as current" {
    _pin 0.8.0 "$BATS_TEST_TMPDIR/no-such-origin.git"
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor

    local vline
    vline=$(_line "could not reach origin")
    [ -n "$vline" ]
    # SKIP-shaped: the probe could not read its input. L-575 / T-2916 — this must not
    # be reported the same way as a probe that read the input and found nothing, which
    # is exactly what a silent pass would do.
    [[ "$vline" == *"SKIP"* ]]
    [[ "$vline" == *"UNKNOWN"* ]]
    [[ "$vline" != *"WARN"* ]]
    # Distinct from BOTH of the other two states.
    [[ "$output" != *"designer pin current with origin"* ]]
    [[ "$output" != *"designer pin is behind its origin"* ]]
    # Non-failing: an unreadable origin is not a doctor failure, and the bounded
    # probe returns rather than hanging (a hang would time this test out, not fail it).
    [ "$status" -eq 0 ]
}
