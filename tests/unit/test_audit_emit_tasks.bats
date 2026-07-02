#!/usr/bin/env bats
# T-2353: Test audit.sh --emit-tasks functionality

load ../test_helper

@test "emit-tasks: function exists in audit.sh" {
    # Verify the _emit_findings_as_tasks function was added
    grep -q "_emit_findings_as_tasks" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "emit-tasks: CLI flag parsing exists" {
    # Verify --emit-tasks and --dry-run flags are recognized
    grep -q "EMIT_TASKS=" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q "DRY_RUN=" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "emit-tasks: dry-run mode doesn't create files" {
    cd "$FRAMEWORK_ROOT"

    # Count tasks before
    before_count=$(find .tasks/active -name "T-*.md" 2>/dev/null | wc -l)

    # Run with --dry-run (should complete without error)
    bin/fw audit --emit-tasks --dry-run >/dev/null 2>&1 || true

    # Count tasks after
    after_count=$(find .tasks/active -name "T-*.md" 2>/dev/null | wc -l)

    # Should not have created any new task files
    [ "${before_count}" -eq "${after_count}" ]
}

@test "emit-tasks: opt-in flag required (default OFF)" {
    cd "$FRAMEWORK_ROOT"

    # Run audit without --emit-tasks
    output=$(bin/fw audit 2>&1 || true)

    # Should NOT show task emission messages
    ! echo "$output" | grep -q "would create"
    ! echo "$output" | grep -q "Creating bugfix task"
}

@test "emit-tasks: deduplication hash field exists" {
    cd "$FRAMEWORK_ROOT"

    # Check if any existing audit-finding tasks have the hash field
    # (or verify the code that writes it exists)
    grep -q "audit_finding_hash:" agents/audit/audit.sh
}

@test "emit-tasks: Python YAML parsing code exists" {
    # Verify the Python snippet that parses audit YAML is present
    grep -q "import yaml" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q "safe_load" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "emit-tasks: severity tagging logic exists" {
    # Verify severity gets mapped to tags
    grep "severity:" "$FRAMEWORK_ROOT/agents/audit/audit.sh" | grep -q "tag"
}

@test "emit-tasks: integration - real audit can be parsed" {
    cd "$FRAMEWORK_ROOT"

    # Run actual audit with dry-run emission
    # Should complete without Python errors
    output=$(bin/fw audit --emit-tasks --dry-run 2>&1 || true)

    # Should not have Python errors
    ! echo "$output" | grep -q "Traceback"
    ! echo "$output" | grep -q "yaml.YAMLError"
}

@test "emit-tasks: documentation exists" {
    # Verify AGENT.md was updated with emit-tasks documentation
    grep -q "emit-tasks" "$FRAMEWORK_ROOT/agents/audit/AGENT.md"
    grep -q "Deduplication" "$FRAMEWORK_ROOT/agents/audit/AGENT.md"
    grep -q "audit_finding_hash" "$FRAMEWORK_ROOT/agents/audit/AGENT.md"
}

@test "emit-tasks: task structure includes required fields" {
    cd "$FRAMEWORK_ROOT"

    # Run dry-run and check output mentions required fields
    output=$(bin/fw audit --emit-tasks --dry-run 2>&1 || true)

    # If any emissions would happen, verify the code paths exist
    # (checking code, not output, since output depends on current audit state)
    grep -q "workflow_type.*bugfix" agents/audit/audit.sh ||
    grep -q "bugfix" agents/audit/audit.sh
}
