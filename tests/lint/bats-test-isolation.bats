#!/usr/bin/env bats
#
# T-4379 — the test-isolation lint (tools/bats-test-isolation-lint.py).
#
# Three recurring defect classes (arc-026, docs/reports/T-4376-test-suite-refactor.md):
#   live-audit       audit.sh / fw doctor|audit|handover with no temp PROJECT_ROOT
#   repo-state       a repo-root variable joined to /.framework.yaml or /.context/
#   fw-no-temp-root  bin/fw driven with no temp PROJECT_ROOT
#
# Each rule is pinned by a fixture it must catch and one it must let pass. Every
# fixture is written into BATS_TEST_TMPDIR; nothing here is anchored to a live
# test file, because those are exactly what later arc work edits (the baseline
# is the work queue, not something to assert on).

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LINT="$ROOT/tools/bats-test-isolation-lint.py"
    FIX="$BATS_TEST_TMPDIR/f.bats"
    export ROOT LINT FIX
}

_fixture() {
    # BATSTEST, not @test: bats rewrites `@test` lines even inside a quoted
    # heredoc of THIS file (see tests/lint/bats-dead-negation.bats).
    sed 's/^BATSTEST /@test /' > "$FIX"
}

_lint() {
    run python3 "$LINT" "$FIX" --no-baseline "$@"
}

_header() {
    printf '%s\n' 'FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"'
}

# ── live-audit ───────────────────────────────────────────────────────────────

@test "live-audit: audit.sh run with no temp root is flagged" {
    { _header; cat <<'EOF'
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
BATSTEST "x" {
    run "$AUDIT" --section structure
    [ "$status" -eq 0 ]
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"live-audit [new]"* ]]
    [[ "$output" == *"live-audit=1 "* ]]
}

@test "live-audit: bin/fw doctor via bash -c is flagged" {
    { _header; cat <<'EOF'
BATSTEST "x" {
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor 2>&1"
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"live-audit=1 "* ]]
}

@test "live-audit: a temp PROJECT_ROOT exported in setup lets it pass" {
    { _header; cat <<'EOF'
setup() {
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/proj"
}
BATSTEST "x" {
    run "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section structure
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" == *"offenders 0"* ]]
}

@test "live-audit: cd back to the repo after a temp setup is flagged again" {
    { _header; cat <<'EOF'
setup() {
    cd "$BATS_TEST_TMPDIR"
}
BATSTEST "x" {
    cd "$FRAMEWORK_ROOT"
    run bin/fw doctor
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"live-audit=1 "* ]]
}

@test "live-audit: an inline PROJECT_ROOT pointing at the repo does not count as temp" {
    { _header; cat <<'EOF'
BATSTEST "x" {
    run env PROJECT_ROOT="$BATS_TEST_DIRNAME/../.." "$FRAMEWORK_ROOT/bin/fw" doctor
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"live-audit=1 "* ]]
}

@test "live-audit: a command line passed as DATA to a classifier is not a run" {
    { _header; cat <<'EOF'
BATSTEST "x" {
    assert_allowed "cd $FRAMEWORK_ROOT && bin/fw doctor"
    run gate 'bin/fw handover'
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" == *"offenders 0"* ]]
}

@test "live-audit: a run inside a quoted command substitution is still a run" {
    { _header; cat <<'EOF'
BATSTEST "x" {
    out="$(cd "$FRAMEWORK_ROOT" && bash agents/audit/audit.sh --check fabric-coverage 2>&1 || true)"
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"live-audit=1 "* ]]
}

# ── repo-state ───────────────────────────────────────────────────────────────

@test "repo-state: reading the repo's .framework.yaml is flagged" {
    { _header; cat <<'EOF'
BATSTEST "x" {
    grep -q CONTEXT_WINDOW "$FRAMEWORK_ROOT/.framework.yaml"
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"repo-state [new]"* ]]
}

@test "repo-state: reading the repo's .context/ through BATS_TEST_DIRNAME is flagged" {
    cat <<'EOF' | _fixture
BATSTEST "x" {
    cat "$BATS_TEST_DIRNAME/../../.context/working/focus.yaml"
}
EOF
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"repo-state=1 "* ]]
}

@test "repo-state: a temp project's .context/ passes" {
    { _header; cat <<'EOF'
setup() {
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/proj"
}
BATSTEST "x" {
    mkdir -p "$PROJECT_ROOT/.context/working"
    grep -q x "$BATS_TEST_TMPDIR/.framework.yaml"
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" == *"offenders 0"* ]]
}

# ── fw-no-temp-root ──────────────────────────────────────────────────────────

@test "fw-no-temp-root: bin/fw driven with no temp root is flagged" {
    { _header; cat <<'EOF'
FW="$FRAMEWORK_ROOT/bin/fw"
BATSTEST "x" {
    run "$FW" task update T-9999 --status work-completed
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"fw-no-temp-root [new]"* ]]
}

@test "fw-no-temp-root: an inline temp PROJECT_ROOT, a cd into a temp dir, --help and an explicit target pass" {
    { _header; cat <<'EOF'
BATSTEST "x" {
    run env PROJECT_ROOT="$BATS_TEST_TMPDIR/p" "$FRAMEWORK_ROOT/bin/fw" task list
    ( cd "$proj" && "$FRAMEWORK_ROOT/bin/fw" context generate-episodic T-1 )
    run "$FRAMEWORK_ROOT/bin/fw" verify-acs --help
    run "$FRAMEWORK_ROOT/bin/fw" init "$BATS_TEST_TMPDIR/p"
    run "$FRAMEWORK_ROOT/bin/fw" vendor --target "$dest"
    line=$("$BATS_TEST_TMPDIR/p/.agentic-framework/bin/fw" version)
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" == *"offenders 0"* ]]
}

# ── parsing ──────────────────────────────────────────────────────────────────

@test "heredoc bodies and comments are data, not code" {
    { _header; cat <<'EOF'
BATSTEST "x" {
    # run "$FRAMEWORK_ROOT/bin/fw" doctor
    cat > "$BATS_TEST_TMPDIR/s.sh" <<'INNER'
"$FRAMEWORK_ROOT/bin/fw" doctor
grep x "$FRAMEWORK_ROOT/.framework.yaml"
INNER
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 0 ]
    [[ "$output" == *"offenders 0"* ]]
}

# ── allow comments ───────────────────────────────────────────────────────────

@test "allow: line, block and file level suppress only the named rule" {
    { _header; cat <<'EOF'
# test-isolation: allow repo-state — this file pins the live config on purpose
BATSTEST "line" {
    # test-isolation: allow live-audit — pins the real doctor wiring
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    grep -q x "$FRAMEWORK_ROOT/.framework.yaml"
}
BATSTEST "block" {
    # test-isolation: allow all — exercises the inherited environment
    run "$FRAMEWORK_ROOT/bin/fw" task list
}
BATSTEST "wrong rule" {
    # test-isolation: allow live-audit — does not cover fw-no-temp-root
    run "$FRAMEWORK_ROOT/bin/fw" task list
}
EOF
    } | _fixture
    _lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"offenders 1 (live-audit=0 repo-state=0 fw-no-temp-root=1)"* ]]
    # line 14 is the run in "wrong rule" (header, file allow, then the blocks)
    [[ "$output" == *"f.bats:14: fw-no-temp-root"* ]]
}

# ── baseline (ratchet) ───────────────────────────────────────────────────────

@test "baseline: old offenders pass, one more in the same file is new" {
    { _header; cat <<'EOF'
BATSTEST "x" {
    run "$FRAMEWORK_ROOT/bin/fw" task list
}
EOF
    } | _fixture
    local base="$BATS_TEST_TMPDIR/base.txt"
    run python3 "$LINT" "$FIX" --baseline "$base" --write-baseline
    [ "$status" -eq 0 ]
    grep -q "^fw-no-temp-root .*f.bats 1$" "$base"

    run python3 "$LINT" "$FIX" --baseline "$base"
    [ "$status" -eq 0 ]
    [[ "$output" == *"new 0"* ]]

    printf '%s\n' 'BATSTEST "y" {' '    run "$FRAMEWORK_ROOT/bin/fw" task show T-1' '}' >> "$FIX"
    sed -i 's/^BATSTEST /@test /' "$FIX"
    run python3 "$LINT" "$FIX" --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"new 2"* ]]
    [[ "$output" == *"2 now, baseline 1"* ]]
}

@test "no .bats files is a usage error, not a clean pass" {
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    run python3 "$LINT" "$BATS_TEST_TMPDIR/empty"
    [ "$status" -eq 2 ]
}
