#!/usr/bin/env bats
# T-3070 — 'agents/audit/audit.sh schedule install' used to be a SECOND,
# independent generator for the same git-tracked crontab source file
# ($PROJECT_ROOT/.context/cron/agentic-audit.crontab) that 'fw cron
# generate'/'fw cron install' (T-1112/T-1114) already own. Its hardcoded
# heredoc template silently overwrote any registry-sourced schedule fix —
# confirmed live 2026-08-23: three T-3070 collision fixes made via the
# registry were reverted by a single 'fw audit schedule install' call.
#
# Pins the fix: when a project has a cron-registry.yaml, 'audit.sh schedule
# install' must delegate to 'fw cron install' (registry-driven) instead of
# regenerating from its own template. The hardcoded template remains only
# for pre-T-448 consumer projects with no registry file.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-schedule-install"
    TEST_CRON_DIR="$TEST_TEMP_DIR/etc-cron-d"
    mkdir -p "$TEST_PROJECT/.context/cron" \
             "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.context/audits/cron" \
             "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates" \
             "$TEST_CRON_DIR"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
    export FW_CRON_INSTALL_DIR="$TEST_CRON_DIR"
    CRON_SOURCE="$TEST_PROJECT/.context/cron/agentic-audit.crontab"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_write_distinctive_registry() {
    cat > "$TEST_PROJECT/.context/cron-registry.yaml" << 'EOF'
jobs:
  - id: distinctive-marker-job
    name: "Distinctive marker job"
    schedule: "17 3 * * *"
    command: "fw audit --section observations --cron"
    source_file: agentic-audit.crontab
    origin_task: T-test
    status: active
    description: "test"
EOF
}

@test "T-3070: with a registry present, 'audit.sh schedule install' writes registry content, not the hardcoded template" {
    _write_distinctive_registry

    run "$FRAMEWORK_ROOT/agents/audit/audit.sh" schedule install
    [ "$status" -eq 0 ]

    # Registry-sourced marker job must be present.
    grep -q "Distinctive marker job" "$CRON_SOURCE"
    grep -q "17 3 \* \* \*" "$CRON_SOURCE"

    # The hardcoded legacy template's signature comment must NOT be present —
    # its presence would mean the heredoc path ran instead of delegation.
    ! grep -q "T-184 + T-196 + T-602 + T-604" "$CRON_SOURCE"
}

@test "T-3070: delegation installs to the system cron dir via 'fw cron install' semantics (in-sync on second run)" {
    _write_distinctive_registry

    run "$FRAMEWORK_ROOT/agents/audit/audit.sh" schedule install
    [ "$status" -eq 0 ]

    run "$FRAMEWORK_ROOT/agents/audit/audit.sh" schedule install
    [ "$status" -eq 0 ]
    [[ "$output" == *"in sync"* ]]
}

@test "T-3070: with NO registry present, the legacy hardcoded template path still works (pre-T-448 consumer compat)" {
    rm -f "$TEST_PROJECT/.context/cron-registry.yaml"

    run "$FRAMEWORK_ROOT/agents/audit/audit.sh" schedule install
    [ "$status" -eq 0 ]
    grep -q "T-184 + T-196 + T-602 + T-604" "$CRON_SOURCE"
}

@test "T-3070: 'fw cron generate' points its install hint at 'fw cron install', not the legacy dual-writer" {
    run grep -n "Install with:" "$FRAMEWORK_ROOT/bin/fw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw cron install"* ]]
    [[ "$output" != *"fw audit schedule install"* ]]
}
