#!/usr/bin/env bats
# T-1943 — Pin fw audit registry → generated cron drift FAIL (audit-side
# sibling to T-1942's doctor-side WARN). Origin: T-1935 — registry edited
# but `fw cron generate` was never run; doctor reported "in sync" for
# 3+ days while the new cron entry was invisible to the OS scheduler.
#
# T-1771 wired audit to detect generated→deployed drift as FAIL. This test
# pins the registry→generated leg at the same FAIL severity, since the same
# "tasks won't run" class applies.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-cron-gen-audit"
    TEST_CRON_DIR="$TEST_TEMP_DIR/etc-cron-d"
    mkdir -p "$TEST_PROJECT/.context/cron" \
             "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.context/audits" \
             "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates" \
             "$TEST_CRON_DIR"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
    export FW_CRON_INSTALL_DIR="$TEST_CRON_DIR"
    PROJECT_SLUG="$(basename "$TEST_PROJECT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')"
    DEPLOYED_PATH="$TEST_CRON_DIR/agentic-audit-${PROJECT_SLUG}"
    SOURCE_PATH="$TEST_PROJECT/.context/cron/agentic-audit.crontab"
    REGISTRY_PATH="$TEST_PROJECT/.context/cron-registry.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_one_job_registry() {
    cat > "$REGISTRY_PATH" <<'EOF'
jobs:
  - id: t1943-one
    name: "one job"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-1943
    status: active
    description: "first job"
EOF
}

_two_job_registry() {
    cat > "$REGISTRY_PATH" <<'EOF'
jobs:
  - id: t1943-one
    name: "one job"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-1943
    status: active
    description: "first job"
  - id: t1943-two
    name: "two job"
    schedule: "15 * * * *"
    command: "fw bvp estimator sweep"
    source_file: agentic-audit.crontab
    origin_task: T-1943
    status: active
    description: "second job — added but not regenerated (T-1935 class)"
EOF
}

_run_structure_audit() {
    run "$FRAMEWORK_ROOT/bin/fw" audit --section structure
}

@test "T-1943: registry ahead of generated → FAIL with 'Run: fw cron generate'" {
    _one_job_registry
    "$FRAMEWORK_ROOT/bin/fw" cron generate >/dev/null
    cp "$SOURCE_PATH" "$DEPLOYED_PATH"
    _two_job_registry  # bump registry, don't regenerate

    _run_structure_audit
    [[ "$output" == *"[FAIL]"*"Cron drift:"*"registry edited but not generated"* ]]
    [[ "$output" == *"Run: fw cron generate"* ]]
}

@test "T-1943: clean state → PASS, no registry-generated FAIL line" {
    _two_job_registry
    "$FRAMEWORK_ROOT/bin/fw" cron generate >/dev/null
    cp "$SOURCE_PATH" "$DEPLOYED_PATH"

    _run_structure_audit
    [[ "$output" == *"Cron registry in sync with $DEPLOYED_PATH"* ]]
    [[ "$output" != *"registry edited but not generated"* ]]
}

@test "T-1943: modify-in-place (schedule change, same job count) → FAIL" {
    # Content-comparison, not just job-count.
    _one_job_registry
    "$FRAMEWORK_ROOT/bin/fw" cron generate >/dev/null
    cp "$SOURCE_PATH" "$DEPLOYED_PATH"
    sed -i 's|schedule: "0 0 \* \* \*"|schedule: "30 2 * * *"|' "$REGISTRY_PATH"

    _run_structure_audit
    [[ "$output" == *"[FAIL]"*"Cron drift:"*"registry edited but not generated"* ]]
}
