#!/usr/bin/env bats
# Unit tests for agents/audit/audit.sh
# Origin: T-924

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

# T-3328: audit.sh exit codes are three different answers, not one scale:
#   0/1 = ran, clean/warnings (green); 2 = ran, found FAILs (a real red);
#   75  = COULD NOT run — another audit holds the lock (T-2930).
# Asserting [ "$status" -le 1 ] conflated 2 with 75: under any concurrency
# (this suite's own earlier tests, a pre-push gate, the daily cron) 9 tests
# here went RED for a reason unrelated to the code under test (observed live
# 2026-08-25, T-3129: 9/14 unit-suite failures were lock contention).
# Contention is not a verdict either way — it reports as a skip, with reason.
#
# Reads the $status/$output globals `run` sets; an explicit $1 overrides the
# status for the hermetic control tests below (skip inside `run`'s subshell
# cannot skip the calling test, which is what makes those tests possible —
# they assert the marker line the contention branch prints before skipping).
_assert_audit_ran() {
    local st="${1-$status}"
    if [ "$st" -eq 75 ]; then
        echo "audit lock contention (exit 75, T-2930/T-3297) — could not run, not a verdict"
        skip "audit lock contention (exit 75) — could not run, not a verdict"
    fi
    # T-4372: these tests run the audit against the LIVE repo, so exit 2 is a
    # verdict on the corpus, not on audit.sh (mutable-corpus anchor, T-3326).
    # Treating it as red made one live FAIL self-sustaining: the red test is
    # itself a NEW red in the next unit-suite report, which the structure
    # section FAILs on. Exit 2 with a complete report means the audit RAN;
    # exit 2 with a truncated one (a crash) still fails.
    if [ "$st" -eq 2 ] && [[ "${output-}" == *"=== SUMMARY ==="* ]] \
        && [[ "${output-}" == *"=== END AUDIT ==="* ]]; then
        return 0
    fi
    if [ "$st" -gt 1 ]; then
        echo "audit exited $st — crashed or stopped before its summary. Output:"
        echo "$output"
        return 1
    fi
    return 0
}

# --- Help ---

@test "audit --help shows usage" {
    run "$AUDIT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--section"* ]]
    [[ "$output" == *"--quiet"* ]]
}

# --- Section filtering ---

@test "audit runs structure section" {
    run "$AUDIT" --section structure
    # Should complete with status 0 or 1 (warnings); 75 = contention → skip
    _assert_audit_ran
    [[ "$output" == *"STRUCTURE"* ]]
}

@test "audit runs compliance section" {
    run "$AUDIT" --section compliance
    _assert_audit_ran
    [[ "$output" == *"COMPLIANCE"* ]] || [[ "$output" == *"TASK"* ]]
}

@test "audit runs traceability section" {
    run "$AUDIT" --section traceability
    _assert_audit_ran
    [[ "$output" == *"TRACEABILITY"* ]] || [[ "$output" == *"GIT"* ]]
}

# --- Output format ---

@test "audit output contains PASS/WARN/FAIL markers" {
    run "$AUDIT" --section structure
    _assert_audit_ran
    # Should have at least one PASS
    [[ "$output" == *"PASS"* ]]
}

@test "audit output contains AUDIT REPORT header" {
    run "$AUDIT" --section structure
    _assert_audit_ran
    [[ "$output" == *"AUDIT REPORT"* ]]
}

@test "audit output contains timestamp" {
    run "$AUDIT" --section structure
    _assert_audit_ran
    [[ "$output" == *"Timestamp"* ]]
}

# --- Live smoke (T-4372 rule) ---

@test "the live structure section completes with a full report" {
    # A smoke, not a contract: the live corpus decides the verdict, so exit 2
    # with a complete report counts as "ran" (T-4372). The exit-code contract
    # is asserted against the synthetic project below, where it is known.
    run "$AUDIT" --section structure
    _assert_audit_ran
    [[ "$output" == *"=== END AUDIT ==="* ]]
}

# --- Exit-code and --quiet contracts: a synthetic project (T-4383) ---
# The live repo cannot answer "does audit exit 0 when everything passes" — its
# verdict moves with the corpus (T-3326). These tests point audit.sh at a
# synthetic project in a private temp root (PROJECT_ROOT overrides the git
# toplevel in lib/paths.sh) and run the "tree" section, whose inputs are just
# a git index and a secret-scan catalogue. Every write lands under that root
# (lock, dated YAML, timing ledger), so there is no contention with live audits
# and nothing to clean up in the repo. The catalogue is private too, so a
# change to the repo's real patterns cannot move these verdicts.

_synthetic_project() {
    local root="$BATS_TEST_TMPDIR/synthetic-project"
    mkdir -p "$root/.context"
    git -C "$root" init -q
    printf '# synthetic catalogue (T-4383)\nT-4383 Seed Marker\tT4383SEED[0-9]{6}\n' \
        > "$root/.secret-scan-patterns"
    printf 'hello\n' > "$root/README.md"
    git -C "$root" add README.md .secret-scan-patterns
    git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -qm init
    echo "$root"
}

# Runs audit.sh on the synthetic project. Path vars inherited from a caller
# (bin/fw exports them) are dropped so they re-derive from PROJECT_ROOT, and
# notifications are off so a seeded FAIL pushes nothing.
_audit_synthetic() {
    local root="$1"; shift
    env -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY \
        NTFY_ENABLED=false PROJECT_ROOT="$root" "$AUDIT" --section tree "$@"
}

@test "audit exits 0 for all-pass sections (synthetic project)" {
    local root; root=$(_synthetic_project)
    run _audit_synthetic "$root"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[PASS] Secret scan: tracked tree clean"* ]]
    [[ "$output" != *"[FAIL]"* ]]
    [[ "$output" != *"[WARN]"* ]]
}

@test "audit exits 2 on a seeded FAIL (synthetic project)" {
    local root; root=$(_synthetic_project)
    # Built from two halves so this file never contains the marker itself.
    printf 'token=%s%s\n' "T4383SEED" "123456" > "$root/leak.txt"
    git -C "$root" add leak.txt
    git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -qm leak
    run _audit_synthetic "$root"
    echo "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"[FAIL] Secret scan: 1 finding(s) in tracked tree"* ]]
    [[ "$output" == *"=== END AUDIT ==="* ]]
}

@test "audit --quiet suppresses terminal output (synthetic project)" {
    local root; root=$(_synthetic_project)
    # Control: the same run without --quiet prints the report, so an empty
    # quiet run is suppression and not an audit that printed nothing anyway.
    run _audit_synthetic "$root"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== AUDIT REPORT ==="* ]]
    run _audit_synthetic "$root" --quiet
    echo "quiet output: [$output]"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "audit --quiet keeps the exit code on a seeded FAIL (synthetic project)" {
    local root; root=$(_synthetic_project)
    printf 'token=%s%s\n' "T4383SEED" "654321" > "$root/leak.txt"
    git -C "$root" add leak.txt
    git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -qm leak
    run _audit_synthetic "$root" --quiet
    echo "quiet output: [$output]"
    [ "$status" -eq 2 ]
    [ -z "$output" ]
}

# --- YAML output ---

@test "audit --output writes YAML report" {
    local tmpdir
    tmpdir=$(mktemp -d)
    run "$AUDIT" --section structure --output "$tmpdir"
    _assert_audit_ran
    # Should create a YAML file in the output dir
    local yaml_count
    yaml_count=$(ls "$tmpdir"/*.yaml 2>/dev/null | wc -l)
    [ "$yaml_count" -ge 1 ]
    rm -rf "$tmpdir"
}

@test "audit YAML report is valid" {
    local tmpdir
    tmpdir=$(mktemp -d)
    # T-3315: run + -le 1 — a bare call made the audit's legitimate exit 1
    # (warnings on a live repo) fail the test before its actual subject, the
    # YAML assertion, ever ran.
    run "$AUDIT" --section structure --output "$tmpdir"
    [ "$status" -eq 75 ] && skip "audit lock contention (T-2930/T-3297) — no verdict, not a failure"
    _assert_audit_ran
    local yaml_file
    yaml_file=$(ls "$tmpdir"/*.yaml 2>/dev/null | head -1)
    # T-3315: assert the report exists — the old `if -n` guard turned a
    # missing report into a silent pass.
    [ -n "$yaml_file" ]
    run python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))"
    [ "$status" -eq 0 ]
    rm -rf "$tmpdir"
}

# --- T-3328 control leg: helper discrimination, hermetic ---
# Stub scripts stand in for audit.sh so these tests never touch the real audit
# lock. Each stub is run through `run` so the helper reads the same $status/
# $output globals the real tests feed it. `skip` inside `run`'s command
# substitution exits that subshell only (it cannot skip the calling test) —
# so the 75 case is observable here as exit 0 plus the contention marker the
# helper prints before skipping, while a real test calling the helper
# directly (outside `run`) skips as intended.

_audit_exit_stub() {
    local code="$1" stub="$BATS_TEST_TMPDIR/stub-audit-$1.sh"
    printf '#!/bin/sh\necho "STUB AUDIT (exit %s)"\nexit %s\n' "$code" "$code" > "$stub"
    chmod +x "$stub"
    echo "$stub"
}

@test "T-3328 control: stubbed exit 75 routes to skip, not pass or fail" {
    run "$(_audit_exit_stub 75)"
    [ "$status" -eq 75 ]
    run _assert_audit_ran
    [ "$status" -eq 0 ]
    [[ "$output" == *"lock contention"* ]]
}

@test "T-3328 control: stubbed exit 2 without a complete report still fails" {
    run "$(_audit_exit_stub 2)"
    [ "$status" -eq 2 ]
    run _assert_audit_ran
    [ "$status" -eq 1 ]
    [[ "$output" == *"audit exited 2"* ]]
    [[ "$output" != *"lock contention"* ]]
}

@test "T-4372 control: stubbed exit 2 with a complete report passes (live corpus FAIL is not a test red)" {
    local stub="$BATS_TEST_TMPDIR/stub-audit-2-full.sh"
    printf '#!/bin/sh\necho "=== STRUCTURE CHECKS ==="\necho "[FAIL] something in the live corpus"\necho "=== SUMMARY ==="\necho "=== END AUDIT ==="\nexit 2\n' > "$stub"
    chmod +x "$stub"
    run "$stub"
    [ "$status" -eq 2 ]
    run _assert_audit_ran
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-4372 control: stubbed exit 2 with SUMMARY but no END (truncated) still fails" {
    local stub="$BATS_TEST_TMPDIR/stub-audit-2-trunc.sh"
    printf '#!/bin/sh\necho "=== SUMMARY ==="\nexit 2\n' > "$stub"
    chmod +x "$stub"
    run "$stub"
    run _assert_audit_ran
    [ "$status" -eq 1 ]
}

@test "T-3328 control: stubbed exit 1 passes (warnings stay green)" {
    run "$(_audit_exit_stub 1)"
    [ "$status" -eq 1 ]
    run _assert_audit_ran
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-3328 control: stubbed exit 0 passes" {
    run "$(_audit_exit_stub 0)"
    [ "$status" -eq 0 ]
    run _assert_audit_ran
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
