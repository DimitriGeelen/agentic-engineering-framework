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

# --- T-100146 (OBS-082): emitted tasks are backlog proposals ---

@test "emit-tasks: create call never passes --start and uses horizon later (T-100146)" {
    # --start makes create-task.sh set started-work AND reassign session focus
    # (create-task.sh: context.sh focus under START_WORK) — an unattended cron
    # doing that steals focus from a live interactive session (OBS-082 incident:
    # T-100141 grabbed focus from T-100140 and tripped G-020 on the next call).
    local block
    block=$(sed -n '/bin\/fw" task create/,/2>&1)/p' "$FRAMEWORK_ROOT/agents/audit/audit.sh")
    [ -n "$block" ]
    ! echo "$block" | grep -q -- "--start"
    echo "$block" | grep -q -- "--horizon later"
}

@test "emit-tasks: focus reassignment in create-task.sh only fires under --start (T-100146)" {
    # The only focus call in create-task.sh must sit inside the START_WORK guard,
    # so a plain (captured) create can never touch focus.yaml.
    local script="$FRAMEWORK_ROOT/agents/task-create/create-task.sh"
    [ "$(grep -c "context.sh\" focus" "$script")" -eq 1 ]
    grep -B3 "context.sh\" focus" "$script" | grep -q "START_WORK"
}

# --- T-100136: single tags: key in emitted frontmatter ---

@test "emit-tasks: injection sed deletes the template tags line (T-100136)" {
    # The injected 'tags: [audit-finding, ...]' must be the ONLY tags: key —
    # a surviving template 'tags: []' wins YAML last-key-wins and silently
    # discards the audit-finding tags.
    grep -q "0,/\^tags: \\\\\[\\\\\]\$/" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "emit-tasks: no emitted task carries duplicate tags: keys (T-100136 corpus)" {
    cd "$FRAMEWORK_ROOT"
    run python3 -c "
import re, glob, sys
bad = []
for p in glob.glob('.tasks/active/T-*.md') + glob.glob('.tasks/completed/T-*.md'):
    t = open(p).read()
    fm_end = t.find('\n---', 4)
    fm = t[:fm_end] if fm_end > 0 else ''
    if 'audit_finding_hash:' not in fm:
        continue
    n = len(re.findall(r'(?m)^tags: ', fm))
    if n > 1:
        bad.append(p)
if bad:
    print('duplicate tags keys in:', bad[:5])
    sys.exit(1)
"
    [ "$status" -eq 0 ]
}
