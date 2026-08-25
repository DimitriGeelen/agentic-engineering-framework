#!/usr/bin/env bats
#
# T-3138 — no bats assertion in this repo may be one that cannot fail.
#
# Bash exempts a `!`-inverted command from errexit. Bats takes a test's verdict
# from its body's exit status. A `!` line that is not the last statement of its
# body is therefore checked by nothing — and reads exactly like a working
# assertion. 106 of them accumulated across 66 files before anything noticed,
# because a dead assertion and a passing one produce identical output.
#
# The mechanism itself is pinned by running bats on fixtures in
# tests/unit/errexit_negation_mechanism.bats. This file tests the LINT: that it
# finds the shape, and — as much as it matters — that it does not invent it.
#
# Every fixture here is written into BATS_TEST_TMPDIR (L-599). None of the
# assertions is pinned to a live test file: those are exactly what T-3138 edits,
# so a control anchored to one would be a report about the corpus rather than a
# check on the lint.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LINT="$ROOT/tools/bats-dead-negation-lint.py"
    FIX="$BATS_TEST_TMPDIR/f.bats"
    export ROOT LINT FIX
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

_lint() {
    run "$LINT" "$FIX"
}

# ── The shape it must catch ──────────────────────────────────────────────────

@test "T-3138/AC2: a non-final bang assertion is flagged" {
    _fixture <<'EOF'
BATSTEST "x" {
    ! grep -q nope file
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'dead negation'
    echo "$output" | grep -q 'dead 1'
}

@test "T-3138/AC2: a FINAL bang assertion is counted live, not flagged" {
    # These fire correctly. Flagging them would make the lint's output mostly
    # noise, and a lint whose output is mostly noise gets an allowance added.
    _fixture <<'EOF'
BATSTEST "x" {
    [ 1 -eq 1 ]
    ! grep -q nope file
}
EOF
    _lint
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'live (final or ||-guarded) 1'
    [[ "$output" != *'dead negation'* ]]
}

@test "T-3138/AC2: trailing comments do not move the last statement" {
    # A comment after the final assertion must not promote the `!` line above it
    # into non-final position — that would be a false positive on a working test.
    _fixture <<'EOF'
BATSTEST "x" {
    ! grep -q nope file
    # closing note
}
EOF
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" != *'dead negation'* ]]
}

@test "T-3138/AC2: every dead site in a multi-test file is reported with its line" {
    _fixture <<'EOF'
BATSTEST "one" {
    ! false
    true
}
BATSTEST "two" {
    true
    ! false
}
BATSTEST "three" {
    ! false
    ! false
}
EOF
    _lint
    [ "$status" -eq 1 ]
    # one dead in "one", none in "two" (final), one dead in "three" (the first).
    echo "$output" | grep -q 'dead 2'
    echo "$output" | grep -q 'live (final or ||-guarded) 2'
    echo "$output" | grep -q ':2: dead negation'
    echo "$output" | grep -q ':10: dead negation'
}

# ── The shapes it must NOT catch ─────────────────────────────────────────────

@test "T-3138/AC2: a bang inside a heredoc body is data, not an assertion" {
    # Suites here write fixture scripts via heredocs constantly. Without heredoc
    # tracking the lint reads their contents as code and reports findings that
    # cannot be fixed — the fastest route to the lint being disabled.
    _fixture <<'EOF'
BATSTEST "x" {
    cat > "$T/script.sh" <<'INNER'
! this is data
still data
INNER
    [ -f "$T/script.sh" ]
}
EOF
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" != *'dead negation'* ]]
}

@test "T-3138/AC2: a here-STRING is not mistaken for a heredoc" {
    # `<<<` consumes no following lines. Treating it as a heredoc would swallow
    # the rest of the file as data and silently hide every real finding below it
    # — a false negative in a lint whose whole job is catching false negatives.
    _fixture <<'EOF'
BATSTEST "x" {
    grep -q hi <<< hi
    ! false
    true
}
EOF
    _lint
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'dead 1'
}

@test "T-3138/AC2: != is a comparison operator, not the negation keyword" {
    _fixture <<'EOF'
BATSTEST "x" {
    [[ "$a" != "$b" ]]
    true
}
EOF
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" != *'dead negation'* ]]
}

@test "T-3138/AC2: code outside any @test block is not scanned" {
    # setup()/teardown() and helper functions run under different errexit rules
    # and are not what this lint reasons about.
    _fixture <<'EOF'
setup() {
    ! false
    true
}
BATSTEST "x" {
    true
}
EOF
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" != *'dead negation'* ]]
}

@test "T-3138/AC2: a ||-guarded negation is live, not dead" {
    # `! cmd || { ...; return 1; }`. The `!` exempts its own pipeline, but the
    # pipeline is not the last command of the `||` list — the guard branch is,
    # and errexit checks it normally. The first draft of this lint flagged four
    # such sites in this repo; all four enforce correctly.
    _fixture <<'EOF'
BATSTEST "x" {
    ! false || { echo boom; return 1; }
    true
}
EOF
    _lint
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'live (final or ||-guarded) 1'
}

@test "T-3138/AC2: a || inside quotes does not count as a guard" {
    # The guard test has to be quote-aware or it reads shell operators out of
    # string literals and silently reclassifies real dead assertions as live —
    # a false negative in the direction that hides work.
    _fixture <<'EOF'
BATSTEST "x" {
    ! _allowed 'foo || bar'
    true
}
EOF
    _lint
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'dead 1'
}

@test "T-3138/AC2: a continued statement is one statement" {
    # `! grep ... \` + `|| (...; false)` on the next line is a single logical
    # command in final position. Reading the physical lines separately reports it
    # as dead, and a conversion built on that report splices `if` into the middle
    # of a continuation and breaks the file.
    _fixture <<'EOF'
BATSTEST "x" {
    true
    ! grep -q nope file \
        || (echo leaked; false)
}
EOF
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" != *'dead negation'* ]]
}

# ── The gate itself ──────────────────────────────────────────────────────────

@test "T-3138/AC3: the live tests/ tree has no dead negations" {
    # The gate. Deliberately a zero-tolerance assertion with no allowance: an
    # allowance is a number somebody has to remember to shrink, and the reason
    # this defect reached 106 is that nothing ever prompted anyone to look.
    run "$LINT" "$ROOT/tests"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'clean: no assertions in dead position'
}

@test "T-3138/AC3 [regression guard]: the lint exits 2 rather than 0 on an empty scan" {
    # A lint that reports success when it scanned nothing is the exact false-zero
    # this repo keeps finding (T-3140, L-575). Pointed at a directory with no
    # .bats files it must refuse, not agree.
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    run "$LINT" "$BATS_TEST_TMPDIR/empty"
    [ "$status" -eq 2 ]
}
