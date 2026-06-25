#!/usr/bin/env bats
# T-2353 (T-2352 Slice 1) — Pin audit --emit-tasks: convert WARN/FAIL findings
# into deduped bugfix tasks. Drives lib/audit_emit.sh directly with fixture
# findings files (running the real `fw audit` takes >5min) and a stub `fw` so no
# real `.tasks/` is touched.
#
# Cases (mirror the task ACs):
#   (a) 0 findings (PASS/INFO only)        → no task created
#   (b) 1 new FAIL                         → 1 task, severity=fail, dedupe key written
#   (c) 1 new WARN                         → 1 task, severity=warn
#   (d) re-run same finding                → dedupe: 0 created, 1 skipped
#   (e) mixed 2 new + 1 already-hashed     → 2 created, 1 skipped
#   (f) dry-run                            → reports would-create, writes nothing

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$TEST_TEMP_DIR/bin"

    # Stub `fw`: emulates `fw task create` enough for the emitter — prints a fresh
    # T-9000+ id and writes a minimal task file with an `id:` line into $TASKS_DIR.
    export STUB_COUNTER="$TEST_TEMP_DIR/.counter"
    cat > "$TEST_TEMP_DIR/bin/fw" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "task" ] && [ "$2" = "create" ]; then
    shift 2
    name=""
    while [ $# -gt 0 ]; do
        case "$1" in --name) name="$2"; shift 2 ;; *) shift ;; esac
    done
    n=$(( $(cat "$STUB_COUNTER" 2>/dev/null || echo 9000) + 1 )); echo "$n" > "$STUB_COUNTER"
    tid="T-$n"
    slug=$(printf '%s' "$name" | tr 'A-Z ' 'a-z-' | sed 's/[^a-z0-9-]//g' | cut -c1-30)
    printf 'id: %s\nname: "%s"\nworkflow_type: build\n' "$tid" "$name" \
        > "$TASKS_DIR/active/${tid}-${slug}.md"
    echo "Created $tid"
fi
STUB
    chmod +x "$TEST_TEMP_DIR/bin/fw"
    export FW_BIN="$TEST_TEMP_DIR/bin/fw"

    source "$FRAMEWORK_ROOT/lib/audit_emit.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_count_active() { ls "$TASKS_DIR"/active/T-*.md 2>/dev/null | wc -l | tr -d ' '; }

@test "t2353:a 0 findings (PASS/INFO only) → no task created" {
    cat > "$TEST_TEMP_DIR/f.txt" <<'EOF'
PASS|Framework installation|
INFO|Session tokens 2.7M|
EOF
    run audit_emit_findings_as_tasks "$TEST_TEMP_DIR/f.txt" false
    [ "$status" -eq 0 ]
    [ "$(_count_active)" -eq 0 ]
    [[ "$output" == *"created=0 skipped=0"* ]]
}

@test "t2353:b 1 new FAIL → 1 task with severity=fail + dedupe key" {
    cat > "$TEST_TEMP_DIR/f.txt" <<'EOF'
FAIL|Mirror divergence: 1 ref differs|Investigate diff|GIT TRACEABILITY CHECKS
EOF
    run audit_emit_findings_as_tasks "$TEST_TEMP_DIR/f.txt" false
    [ "$status" -eq 0 ]
    [ "$(_count_active)" -eq 1 ]
    local tf; tf=$(ls "$TASKS_DIR"/active/T-*.md)
    grep -q "^audit_severity: fail" "$tf"
    grep -qE "^audit_finding_hash: [0-9a-f]{40}$" "$tf"
}

@test "t2353:c 1 new WARN → 1 task with severity=warn" {
    cat > "$TEST_TEMP_DIR/f.txt" <<'EOF'
WARN|Cron registry edited but not generated|Run fw cron generate|TASK COMPLIANCE CHECKS
EOF
    run audit_emit_findings_as_tasks "$TEST_TEMP_DIR/f.txt" false
    [ "$status" -eq 0 ]
    [ "$(_count_active)" -eq 1 ]
    grep -q "^audit_severity: warn" "$(ls "$TASKS_DIR"/active/T-*.md)"
}

@test "t2353:d re-run same finding → dedupe (0 created, 1 skipped)" {
    cat > "$TEST_TEMP_DIR/f.txt" <<'EOF'
FAIL|Mirror divergence: 1 ref differs|Investigate diff|GIT TRACEABILITY CHECKS
EOF
    audit_emit_findings_as_tasks "$TEST_TEMP_DIR/f.txt" false   # first run files it
    [ "$(_count_active)" -eq 1 ]
    run audit_emit_findings_as_tasks "$TEST_TEMP_DIR/f.txt" false   # second run dedupes
    [ "$status" -eq 0 ]
    [ "$(_count_active)" -eq 1 ]
    [[ "$output" == *"created=0 skipped=1"* ]]
}

@test "t2353:e mixed 2 new + 1 already-hashed → 2 created, 1 skipped" {
    cat > "$TEST_TEMP_DIR/first.txt" <<'EOF'
FAIL|Mirror divergence: 1 ref differs|Investigate diff|GIT TRACEABILITY CHECKS
EOF
    audit_emit_findings_as_tasks "$TEST_TEMP_DIR/first.txt" false   # pre-file one
    [ "$(_count_active)" -eq 1 ]
    cat > "$TEST_TEMP_DIR/mixed.txt" <<'EOF'
FAIL|Mirror divergence: 1 ref differs|Investigate diff|GIT TRACEABILITY CHECKS
WARN|Cron registry edited but not generated|Run fw cron generate|TASK COMPLIANCE CHECKS
WARN|Task debt: 5 stale tasks|Run fw task stale|TASK QUALITY CHECKS
EOF
    run audit_emit_findings_as_tasks "$TEST_TEMP_DIR/mixed.txt" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"created=2 skipped=1"* ]]
    [ "$(_count_active)" -eq 3 ]
}

@test "t2353:f dry-run writes nothing" {
    cat > "$TEST_TEMP_DIR/f.txt" <<'EOF'
FAIL|Mirror divergence: 1 ref differs|Investigate diff|GIT TRACEABILITY CHECKS
WARN|Cron registry edited but not generated|Run fw cron generate|TASK COMPLIANCE CHECKS
EOF
    run audit_emit_findings_as_tasks "$TEST_TEMP_DIR/f.txt" true
    [ "$status" -eq 0 ]
    [ "$(_count_active)" -eq 0 ]
    [[ "$output" == *"would create"* ]]
    [[ "$output" == *"created=2 skipped=0 (dry_run=true)"* ]]
}
