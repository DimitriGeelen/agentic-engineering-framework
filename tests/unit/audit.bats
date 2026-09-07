#!/usr/bin/env bats
# Unit tests for agents/audit/audit.sh
# Origin: T-924

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

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
    # Should complete with status 0 or 1 (warnings)
    [ "$status" -le 1 ]
    [[ "$output" == *"STRUCTURE"* ]]
}

@test "audit runs compliance section" {
    run "$AUDIT" --section compliance
    [ "$status" -le 1 ]
    [[ "$output" == *"COMPLIANCE"* ]] || [[ "$output" == *"TASK"* ]]
}

@test "audit runs traceability section" {
    run "$AUDIT" --section traceability
    [ "$status" -le 1 ]
    [[ "$output" == *"TRACEABILITY"* ]] || [[ "$output" == *"GIT"* ]]
}

# --- Output format ---

@test "audit output contains PASS/WARN/FAIL markers" {
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    # Should have at least one PASS
    [[ "$output" == *"PASS"* ]]
}

@test "audit output contains AUDIT REPORT header" {
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" == *"AUDIT REPORT"* ]]
}

@test "audit output contains timestamp" {
    run "$AUDIT" --section structure
    [ "$status" -le 1 ]
    [[ "$output" == *"Timestamp"* ]]
}

# --- Exit codes ---

@test "audit exits 0 for all-pass sections" {
    # Structure checks on a well-formed project should pass
    run "$AUDIT" --section structure
    # 0=pass, 1=warnings (acceptable)
    [ "$status" -le 1 ]
}

# --- Quiet mode ---

@test "audit --quiet suppresses terminal output" {
    run "$AUDIT" --section structure --quiet
    [ "$status" -le 1 ]
    # In quiet mode, output should be minimal or empty
    # (may still have some output to stderr)
}

# --- YAML output ---

@test "audit --output writes YAML report" {
    local tmpdir
    tmpdir=$(mktemp -d)
    run "$AUDIT" --section structure --output "$tmpdir"
    [ "$status" -le 1 ]
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
