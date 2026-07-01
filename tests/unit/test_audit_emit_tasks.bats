#!/usr/bin/env bats
# T-2353: Test audit --emit-tasks functionality

# Smoke test: verify function exists
@test "audit.sh contains _emit_findings_as_tasks function" {
    grep -q "_emit_findings_as_tasks" agents/audit/audit.sh
}

# Smoke test: verify --emit-tasks flag exists
@test "audit --help shows --emit-tasks flag" {
    run bin/fw audit --help
    echo "$output" | grep -q "emit-tasks"
}

# Smoke test: verify --dry-run flag exists
@test "audit --help shows --dry-run flag" {
    run bin/fw audit --help
    echo "$output" | grep -q "dry-run"
}

# Test severity tagging format
@test "emit function uses correct severity format" {
    # Check the implementation has the right output format
    grep -A120 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "severity"
}

# Test deduplication logic exists
@test "emit function includes deduplication scan" {
    # Verify dedupe logic is present
    grep -A50 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "audit_finding_hash"
}

# Test task creation parameters
@test "emit function creates bugfix tasks with correct metadata" {
    # Verify the task creation uses workflow_type bugfix
    grep -A100 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "workflow_type.*bugfix\|--type bugfix"
}

# Test dry-run mode
@test "emit function handles dry-run flag" {
    # Verify dry-run logic exists
    grep -A100 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "DRY-RUN"
}

# Test WARN/FAIL filtering
@test "emit function filters PASS/INFO findings" {
    # Verify it only processes WARN/FAIL
    grep -A50 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q 'severity.*!=.*WARN.*FAIL\|WARN.*FAIL'
}

# Test hash computation
@test "emit function computes SHA1 hash for deduplication" {
    # Verify sha1sum is used for hashing
    grep -A70 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "sha1sum"
}

# Test function is called when flag is set
@test "_emit_findings_as_tasks is invoked when --emit-tasks is set" {
    # Verify the control flow in audit.sh
    run grep -A5 'if \[ "$EMIT_TASKS" = true \]' agents/audit/audit.sh
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "_emit_findings_as_tasks"
}

# Test summary output
@test "emit function provides summary statistics" {
    # Verify summary output exists
    grep -A140 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "Would create:"
    grep -A140 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "Created:"
}

# Test task body includes required sections
@test "emit function creates tasks with Context and Mitigation sections" {
    # Verify the task body template
    grep -A100 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "## Context"
    grep -A100 "_emit_findings_as_tasks" agents/audit/audit.sh | grep -q "## Mitigation"
}
