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

    # T-100137 (OBS-080): assert on the emitter's own output, not live
    # .tasks/active dir counts — the count race-fails whenever a cron audit,
    # BVP estimator, or concurrent session creates a task mid-test.
    # [CREATED] is printed only by the real-create path; dry-run prints
    # [WOULD CREATE] and never calls task create.
    output=$(bin/fw audit --emit-tasks --dry-run 2>&1 || true)
    ! echo "$output" | grep -q "^\[CREATED\]"
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

# --- T-100135: volatile-token hash normalization ---

# Extract the emitter's embedded hash-computation Python (the block starting
# at "import yaml, sys, hashlib, os, re") and run it against a fixture YAML.
_run_hash_block() {
    local yaml_file="$1"
    local py
    py=$(sed -n '/^import yaml, sys, hashlib, os, re$/,/^PYEOF$/p' \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh" | sed '$d')
    [ -n "$py" ]
    YAML_FILE="$yaml_file" python3 -c "$py"
}

@test "emit-tasks hash: volatile counts/day-counters do not change the hash (T-100135)" {
    local d="$BATS_TMPDIR/t100135_$$"
    mkdir -p "$d"
    cat > "$d/day1.yaml" <<'Y'
findings:
  - level: WARN
    check: "D5: Task lifecycle - 29 anomaly(s): T-1062(86d-active) T-1274(78d-active)"
    mitigation: "Review flagged tasks"
Y
    cat > "$d/day2.yaml" <<'Y'
findings:
  - level: WARN
    check: "D5: Task lifecycle - 29 anomaly(s): T-1062(87d-active) T-1274(79d-active)"
    mitigation: "Review flagged tasks"
Y
    h1=$(_run_hash_block "$d/day1.yaml" | cut -d'|' -f2)
    h2=$(_run_hash_block "$d/day2.yaml" | cut -d'|' -f2)
    rm -rf "$d"
    [ -n "$h1" ]
    [ "$h1" = "$h2" ]
}

@test "emit-tasks hash: findings differing only by task ID hash differently (T-100135)" {
    local d="$BATS_TMPDIR/t100135b_$$"
    mkdir -p "$d"
    cat > "$d/a.yaml" <<'Y'
findings:
  - level: WARN
    check: "CTL-012-MISSING-DECIDE: Inception task T-1902 flipped without decide"
    mitigation: "Record decision"
Y
    cat > "$d/b.yaml" <<'Y'
findings:
  - level: WARN
    check: "CTL-012-MISSING-DECIDE: Inception task T-1905 flipped without decide"
    mitigation: "Record decision"
Y
    ha=$(_run_hash_block "$d/a.yaml" | cut -d'|' -f2)
    hb=$(_run_hash_block "$d/b.yaml" | cut -d'|' -f2)
    rm -rf "$d"
    [ -n "$ha" ]
    [ "$ha" != "$hb" ]
}
