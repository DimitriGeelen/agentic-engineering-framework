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
    if [ "$st" -gt 1 ]; then
        echo "audit exited $st — ran and found FAILs (or crashed). Output:"
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

# --- Exit codes ---

@test "audit exits 0 for all-pass sections" {
    # Structure checks on a well-formed project should pass
    run "$AUDIT" --section structure
    # 0=pass, 1=warnings (acceptable); 2=real FAILs still fails; 75=skip
    _assert_audit_ran
}

# --- Quiet mode ---

@test "audit --quiet suppresses terminal output" {
    run "$AUDIT" --section structure --quiet
    _assert_audit_ran
    # In quiet mode, output should be minimal or empty
    # (may still have some output to stderr)
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
    [ "$status" -le 1 ]
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

@test "T-3328 control: stubbed exit 2 still fails (real verdict kept)" {
    run "$(_audit_exit_stub 2)"
    [ "$status" -eq 2 ]
    run _assert_audit_ran
    [ "$status" -eq 1 ]
    [[ "$output" == *"audit exited 2"* ]]
    [[ "$output" != *"lock contention"* ]]
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
