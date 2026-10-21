#!/usr/bin/env bats
#
# T-4521 — tools/bats-heredoc-test-lint.py. Bats <1.11 (Ubuntu 24.04 apt ships
# 1.10) finds tests by scanning source text, heredocs included, so a fixture
# `@test` written through a heredoc becomes a test of the OUTER file; two with
# the same name abort the whole run ("Duplicate test name(s)"). The first test
# is the gate on the live corpus; the rest pin the lint against fixtures so a
# lint that never fires cannot pass as green.
#
# Fixtures here are written with printf on purpose: a heredoc would be the very
# shape under test. `! cmd` at statement position is INERT in bats (L-628).

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LINT="$ROOT/tools/bats-heredoc-test-lint.py"
    FIX="$BATS_TEST_TMPDIR/fixtures"
    mkdir -p "$FIX"
}

@test "corpus: no .bats file under tests/ has an @test inside a heredoc" {
    run python3 "$LINT" "$ROOT/tests"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean: no @test inside a heredoc"* ]]
}

@test "fixture: @test inside a quoted heredoc is flagged with file and line" {
    printf '%s\n' '@test "outer" {' \
        "    cat > \"\$X\" <<'EOF'" \
        '@test "inner" { true; }' \
        'EOF' '}' > "$FIX/bad.bats"
    run python3 "$LINT" "$FIX"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bad.bats:3:"* ]]
}

@test "fixture: unquoted and <<- heredocs are flagged too" {
    printf '%s\n' 'f() {' '    cat > x <<EOF2' '@test "a" { true; }' 'EOF2' \
        '    cat > y <<-EOF' '	@test "b" { true; }' '	EOF' '}' > "$FIX/bad2.bats"
    run python3 "$LINT" "$FIX"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bad2.bats:3:"* ]]
    [[ "$output" == *"bad2.bats:6:"* ]]
}

@test "fixture: the @@test + sed convention, real tests, and <<EOF inside quotes pass" {
    printf '%s\n' '@test "real" {' \
        "    sed 's/^@@test/@test/' > \"\$X\" <<'EOF'" \
        '@@test "inner" { true; }' 'EOF' '}' \
        '@test "names <<EOF in a string" {' \
        "    run classify \"\$(printf \"git commit -F - <<'EOF'\\nbody\\nEOF\\n\")\"" \
        '}' \
        '@test "after the quoted opener" { true; }' \
        '@test "here-string" { grep -q x <<< "x"; }' \
        '@test "still a real test" { true; }' > "$FIX/good.bats"
    run python3 "$LINT" "$FIX"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "fixture: a lint run with no .bats files is a usage error, not a pass" {
    run python3 "$LINT" "$FIX/empty-dir-does-not-exist"
    [ "$status" -eq 2 ]
}
