#!/usr/bin/env bats
# Integration tests for fw cron install + fw doctor cron drift check (T-1112/T-1114)
#
# Uses FW_CRON_INSTALL_DIR override to point at a temp directory instead of
# /etc/cron.d/ so the tests run without root.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    export FW_CRON_INSTALL_DIR="$TEST_TEMP_DIR/etc-cron.d"
    export NO_COLOR=1
    unset _FW_PATHS_LOADED
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/cron" \
             "$FW_CRON_INSTALL_DIR"
    cat > "$PROJECT_ROOT/.framework.yaml" <<'YAML'
version: 1.0.0
YAML

    cat > "$PROJECT_ROOT/.context/cron-registry.yaml" <<'YAML'
jobs:
  - id: probe-1
    name: Probe 1
    schedule: "*/30 * * * *"
    command: "fw audit --cron"
    status: active
  - id: probe-2
    name: Probe 2
    schedule: "0 * * * *"
    command: "echo hello"
    status: active
YAML
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_slug() {
    basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g'
}

@test "fw cron install: dry-run does not create target" {
    run bash -c "cd '$PROJECT_ROOT' && '$FW' cron install --dry-run 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "dry-run" ]]
    local slug; slug=$(_slug)
    [ ! -f "$FW_CRON_INSTALL_DIR/agentic-audit-$slug" ]
}

@test "fw cron install: creates target file on first install" {
    run bash -c "cd '$PROJECT_ROOT' && '$FW' cron install 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Installed" ]]
    local slug; slug=$(_slug)
    [ -f "$FW_CRON_INSTALL_DIR/agentic-audit-$slug" ]
    grep -q "probe-1" "$FW_CRON_INSTALL_DIR/agentic-audit-$slug" || grep -q "Probe 1" "$FW_CRON_INSTALL_DIR/agentic-audit-$slug"
}

@test "fw cron install: is idempotent on second run" {
    bash -c "cd '$PROJECT_ROOT' && '$FW' cron install" >/dev/null 2>&1
    run bash -c "cd '$PROJECT_ROOT' && '$FW' cron install 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "in sync" ]]
}

@test "fw cron install: fails when registry missing" {
    rm "$PROJECT_ROOT/.context/cron-registry.yaml"
    run bash -c "cd '$PROJECT_ROOT' && '$FW' cron install 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "No cron registry" ]]
}

@test "fw cron install: detects drift after registry change" {
    bash -c "cd '$PROJECT_ROOT' && '$FW' cron install" >/dev/null 2>&1
    # Add a new job to the registry
    cat >> "$PROJECT_ROOT/.context/cron-registry.yaml" <<'YAML'
  - id: probe-3
    name: Probe 3
    schedule: "15 * * * *"
    command: "echo added"
    status: active
YAML
    run bash -c "cd '$PROJECT_ROOT' && '$FW' cron install --dry-run 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Pending" ]]
    [[ "$output" =~ "probe-3" || "$output" =~ "Probe 3" ]]
}

@test "fw cron help: documents install subcommand" {
    run bash -c "'$FW' cron help 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "install" ]]
    [[ "$output" =~ "FW_CRON_INSTALL_DIR" ]]
}

@test "fw doctor: reports drift when registry edited after install" {
    bash -c "cd '$PROJECT_ROOT' && '$FW' cron install" >/dev/null 2>&1
    echo "# drift probe" >> "$PROJECT_ROOT/.context/cron/agentic-audit.crontab"
    run bash -c "cd '$PROJECT_ROOT' && '$FW' doctor 2>&1"
    [[ "$output" =~ "Cron registry drift" || "$output" =~ "not installed" ]]
}

@test "fw doctor: reports cron in sync after install" {
    bash -c "cd '$PROJECT_ROOT' && '$FW' cron install" >/dev/null 2>&1
    run bash -c "cd '$PROJECT_ROOT' && '$FW' doctor 2>&1"
    [[ "$output" =~ "Cron registry in sync" ]]
}

@test "fw doctor: warns when generated but not installed" {
    bash -c "cd '$PROJECT_ROOT' && '$FW' cron generate" >/dev/null 2>&1
    run bash -c "cd '$PROJECT_ROOT' && '$FW' doctor 2>&1"
    [[ "$output" =~ "not installed" ]]
}
