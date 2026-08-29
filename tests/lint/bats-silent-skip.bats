#!/usr/bin/env bats
#
# T-3217 — a skipped bats test reports `ok`, and the repo-standard P-011
# verification idiom cannot tell that apart from a test that ran.
#
#     timeout 300 bats <suite> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#
# A skip is not a `not ok`. Found while landing T-3213, whose root-guarded
# `chmod 500` test skipped on every run that mattered — the suite runs as root
# — so the AC it covered was measured nowhere while reporting ok.
#
# This file tests the LINT. The blind spot itself is a property of TAP and needs
# no pinning; what needs pinning is that the detector finds the two shapes it
# claims to and, much more importantly, DOES NOT INVENT THEM. Most skips in this
# corpus are correct — an optional dependency is absent — and a detector that
# reddens those gets suppressed wholesale and then protects nothing. So the
# false-positive legs below are not padding; they are the ones that decide
# whether this tool survives contact.
#
# Every fixture is written into BATS_TEST_TMPDIR (L-599). Nothing here asserts
# against a live test file: the corpus is what T-3217 may edit, so a control
# anchored to one would be a report about the corpus rather than a check on the
# lint.
#
# `! cmd` at statement position is INERT in bats (L-628, T-3199) — this file
# uses `if cmd; then false; fi`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LINT="$ROOT/tools/bats-silent-skip-lint.py"
    FIX="$BATS_TEST_TMPDIR/f.bats"
    export ROOT LINT FIX
}

# BATSTEST, not @test. Bats rewrites every line starting with `@test` when it
# preprocesses THIS file — including inside a quoted heredoc, whose quoting it
# cannot see. A fixture written with a literal `@test` reaches disk already
# transformed, so the file under test is not the file that was written.
_fixture() {
    # SKIPCALL for the same reason as BATSTEST: a literal `skip` call in a
    # fixture is a real call site in THIS file, and the detector scans
    # tests/ — so the lint's own test data would be reported as the lint's
    # own findings. The fixture must not be the thing under test in the host.
    sed -e 's/^BATSTEST /@test /' -e 's/SKIPCALL /skip /g' > "$FIX"
}

_lint() { run "$LINT" "$FIX"; }

# ── the two shapes it must catch ─────────────────────────────────────────────

@test "an unconditional skip is flagged" {
    _fixture <<'EOF'
BATSTEST "x" {
    SKIPCALL "not written yet"
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'UNCONDITIONAL'
}

@test "a standing-configuration guard is flagged — the T-3213 shape" {
    _fixture <<'EOF'
BATSTEST "x" {
    if [ "$(id -u)" -eq 0 ]; then SKIPCALL "chmod does not deny root"; fi
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'STANDING'
}

# ── the legs that decide whether the lint survives contact ───────────────────

@test "an optional-dependency guard is NOT flagged" {
    _fixture <<'EOF'
BATSTEST "x" {
    command -v docker >/dev/null || SKIPCALL "docker not available"
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 0 ]
}

@test "a skip in an else branch is NOT flagged — the if is its guard" {
    _fixture <<'EOF'
BATSTEST "x" {
    if command -v gh >/dev/null; then
        [ 1 -eq 1 ]
    else
        SKIPCALL "gh not installed"
    fi
}
EOF
    _lint
    [ "$status" -eq 0 ]
}

@test "a backslash continuation is anchored to its guard, not read as unconditional" {
    _fixture <<'EOF'
BATSTEST "x" {
    [ -f "$SOMETHING" ] || \
        SKIPCALL "fixture missing"
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 0 ]
}

@test "a variable named skip inside embedded Python is not a call site" {
    # The dependency skip is here so the fixture HAS a call site: a file with
    # none exits 2 (see the empty-scan leg), which would pass this test for
    # entirely the wrong reason.
    _fixture <<'EOF'
BATSTEST "x" {
    command -v jq >/dev/null || SKIPCALL "jq not installed"
    python3 - <<'PY'
SKIPCALL = {"a", "b"}
print(skip)
PY
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 0 ]
    if echo "$output" | grep -q UNCONDITIONAL; then false; fi
}

# ── the scanner must not blind itself: an argument that MENTIONS a heredoc ──
#
# Both of these were REAL false negatives in the first working version, found by
# reconciling the detector's census against a naive grep. A `<<TAG` inside a
# comment or a quoted string opened a heredoc that never closed, and the scanner
# went silent for the REST OF THE FILE — reporting clean. Same family as the
# defect the tool exists to report, and the shape peer 832 named at @804: a
# character scan standing in for shell structure, so an argument that mentions
# a thing is treated as an action on it.

@test "a comment mentioning <<TAG does not blind the scanner" {
    _fixture <<'EOF'
# The hook fires on a $(... <<TAG ... TAG) block in bin/fw.
BATSTEST "x" {
    SKIPCALL "not written yet"
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'UNCONDITIONAL'
}

@test "a quoted string mentioning a heredoc does not blind the scanner" {
    _fixture <<'EOF'
BATSTEST "a" {
    run has_write_pattern "cat <<EOF > file.txt"
    [ 1 -eq 1 ]
}
BATSTEST "b" {
    SKIPCALL "not written yet"
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'UNCONDITIONAL'
}

@test "an apostrophe in a double-quoted string does not desync the quote stripper" {
    # A regex that strips quoted spans pairs this apostrophe with the next real
    # quote and mis-reads everything after it (832's /tmp census hit exactly
    # this). The state machine tracks WHICH quote opened the span.
    _fixture <<'EOF'
BATSTEST "a" {
    run echo "the agent's own output"
    [ 1 -eq 1 ]
}
BATSTEST "b" {
    SKIPCALL "not written yet"
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'UNCONDITIONAL'
}

@test "a scan that found no call sites exits 2, not 0" {
    # A file with no skips must not read as a pass — that is indistinguishable
    # from a scan that examined the wrong path, which is this tool's own class.
    _fixture <<'EOF'
BATSTEST "x" {
    [ 1 -eq 1 ]
}
EOF
    _lint
    [ "$status" -eq 2 ]
}

# ── MUTATION CONTROL ─────────────────────────────────────────────────────────

@test "removing the STANDING comparison stops the standing skip being detected" {
    _fixture <<'EOF'
BATSTEST "x" {
    if [ "$(id -u)" -eq 0 ]; then SKIPCALL "chmod does not deny root"; fi
    [ 1 -eq 1 ]
}
EOF
    # live tool: detects
    run "$LINT" "$FIX"
    [ "$status" -eq 1 ]

    # mutant with the STANDING pattern emptied: must NOT detect
    local mut="$BATS_TEST_TMPDIR/mut.py"
    sed "s|^STANDING = re.compile(.*)$|STANDING = re.compile(r'(?!x)x')|" "$LINT" > "$mut"
    if diff -q "$LINT" "$mut" >/dev/null 2>&1; then
        echo "mutation changed no bytes — STANDING is not where expected" >&2
        false
    fi
    run python3 "$mut" "$FIX"
    [ "$status" -eq 0 ]
}

# ── TAP mode: report what actually happened ──────────────────────────────────

@test "--tap reports a skip that fired" {
    local tap="$BATS_TEST_TMPDIR/t.tap"
    printf '1..2\nok 1 real test\nok 2 other test # skip running as root\n' > "$tap"
    run "$LINT" --tap "$tap"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'FIRED SKIP'
}

@test "--tap does not fail on a dependency skip" {
    local tap="$BATS_TEST_TMPDIR/t.tap"
    printf '1..2\nok 1 real test\nok 2 other # skip docker not available\n' > "$tap"
    run "$LINT" --tap "$tap"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'dependency'
}

@test "--tap on output with no ok lines exits 2, not 0" {
    local tap="$BATS_TEST_TMPDIR/t.tap"
    printf 'bats: command not found\n' > "$tap"
    run "$LINT" --tap "$tap"
    [ "$status" -eq 2 ]
}

@test "the two modes converge on the same fixture by different evidence" {
    # The static scan reads guard SHAPE; the TAP mode reads what a real run
    # DID. Neither can see the other's input. Agreeing on a case built here is
    # the strongest available claim — and it is built here rather than anchored
    # to a live suite, because a live finding is exactly what this task fixes,
    # so such a test would assert that the corpus stays dirty.
    _fixture <<'EOF'
BATSTEST "standing" {
    if [ "$(id -u)" -eq 0 ]; then SKIPCALL "running as root"; fi
    [ 1 -eq 1 ]
}
BATSTEST "real" {
    [ 1 -eq 1 ]
}
EOF
    # static: flags it from the guard's shape
    run "$LINT" "$FIX"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'STANDING'

    # empirical: run it for real and read the TAP. As root the guard is true,
    # so the skip fires; as non-root it does not, and there is nothing to
    # report — assert the two agree rather than assuming a uid.
    local tap="$BATS_TEST_TMPDIR/conv.tap"
    bats --tap "$FIX" > "$tap" 2>&1 || true
    run "$LINT" --tap "$tap"
    if [ "$(id -u)" -eq 0 ]; then
        [ "$status" -eq 1 ]
        echo "$output" | grep -q 'FIRED SKIP'
    else
        [ "$status" -eq 0 ]
    fi
}

# ── the wiring is asserted, not assumed ──────────────────────────────────────

@test "fw test lint invokes the silent-skip detector" {
    grep -q 'bats-silent-skip-lint.py' "$ROOT/bin/fw"
}

@test "fw test lint actually reports a silent-skip section" {
    run bash -c "cd '$ROOT' && timeout 600 bin/fw test lint 2>&1"
    echo "$output" | grep -q 'Silent-Skip'
}
