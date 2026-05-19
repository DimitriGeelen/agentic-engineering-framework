#!/usr/bin/env bats
# T-1771 — Pin audit.sh cron-drift behaviour. Origin: T-1768 GO recommendation
# (e): replicate fw doctor cron-drift check inside fw audit so drift becomes a
# counted failure in the audit summary (visible on /audit page + cron runs),
# not just an advisory line in fw doctor that nobody reads.
#
# T-1767 was the concrete trigger: a cron-touching task closed work-completed
# while drift made the new job a no-op for 3 days.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-cron-drift"
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
    # Project slug used by audit.sh: basename(PROJECT_ROOT) lowercased + sanitized
    PROJECT_SLUG="$(basename "$TEST_PROJECT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')"
    DEPLOYED_PATH="$TEST_CRON_DIR/agentic-audit-${PROJECT_SLUG}"
    SOURCE_PATH="$TEST_PROJECT/.context/cron/agentic-audit.crontab"
    REGISTRY_PATH="$TEST_PROJECT/.context/cron-registry.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_minimal_registry() {
    cat > "$REGISTRY_PATH" <<'EOF'
jobs:
  - id: dummy
    name: "dummy"
    schedule: "0 0 * * *"
    command: "fw audit"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
}

_run_structure_audit() {
    run "$FRAMEWORK_ROOT/bin/fw" audit --section structure
}

@test "in-sync: registry == generated == deployed → PASS, no drift FAIL" {
    _minimal_registry
    # T-1943: must actually generate (not write a stub) so the
    # registry→generated drift check sees a current source.
    "$FRAMEWORK_ROOT/bin/fw" cron generate >/dev/null
    cp "$SOURCE_PATH" "$DEPLOYED_PATH"
    _run_structure_audit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cron registry in sync with $DEPLOYED_PATH"* ]]
    [[ "$output" != *"Cron drift:"*"differs from deployed"* ]]
    [[ "$output" != *"generated but not installed"* ]]
    [[ "$output" != *"registry edited but not generated"* ]]
}

@test "registry vs deployed mismatch → FAIL counted in summary" {
    _minimal_registry
    echo "# version-A" > "$SOURCE_PATH"
    echo "# version-B" > "$DEPLOYED_PATH"
    _run_structure_audit
    # FAILs make audit exit non-zero per audit.sh exit-code policy
    [[ "$output" == *"[FAIL]"*"Cron drift:"*"differs from deployed"* ]]
    [[ "$output" == *"Run: fw cron install"* ]]
    # FAIL is counted in summary
    [[ "$output" == *"Fail: 1"* ]] || [[ "$output" == *"Fail:"*[1-9]* ]]
}

@test "generated but not installed → FAIL" {
    _minimal_registry
    echo "# generated" > "$SOURCE_PATH"
    # No deployed file — DEPLOYED_PATH absent
    _run_structure_audit
    [[ "$output" == *"[FAIL]"*"Cron drift:"*"generated but not installed"* ]]
    [[ "$output" == *"Run: fw cron install"* ]]
}

@test "registry but not generated → WARN (less severe — pre-deployment state)" {
    _minimal_registry
    # No source file, no deployed file
    _run_structure_audit
    [[ "$output" == *"[WARN]"*"Cron drift:"*"registry present but not generated"* ]]
    [[ "$output" != *"[FAIL]"*"Cron drift:"* ]]
}

@test "no registry → check is silent (project doesn't use cron pipeline)" {
    # No registry, no source, no deployed
    _run_structure_audit
    [[ "$output" != *"Cron drift:"* ]]
    [[ "$output" != *"Cron registry in sync"* ]]
}
