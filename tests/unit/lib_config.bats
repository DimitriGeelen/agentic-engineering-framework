#!/usr/bin/env bats
# Unit tests for lib/config.sh — 3-tier configuration resolution
# Origin: T-819

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    source "$FRAMEWORK_ROOT/lib/config.sh"
    # Reset loaded flag so each test gets fresh state
    _FW_CONFIG_LOADED=1
}

# --- fw_config ---

@test "fw_config returns default when no env var or explicit" {
    unset FW_TEST_KEY
    result=$(fw_config "TEST_KEY" "default_val")
    [ "$result" = "default_val" ]
}

@test "fw_config returns env var when FW_KEY is set" {
    result=$(FW_TEST_KEY=from_env fw_config "TEST_KEY" "default_val")
    [ "$result" = "from_env" ]
}

@test "fw_config returns explicit value over env var" {
    result=$(FW_TEST_KEY=from_env fw_config "TEST_KEY" "default_val" "explicit_val")
    [ "$result" = "explicit_val" ]
}

@test "fw_config returns explicit value over default" {
    unset FW_TEST_KEY
    result=$(fw_config "TEST_KEY" "default_val" "explicit_val")
    [ "$result" = "explicit_val" ]
}

@test "fw_config returns empty string explicit as explicit" {
    # Empty string explicit should NOT count as explicit (empty = not provided)
    result=$(FW_TEST_KEY=from_env fw_config "TEST_KEY" "default_val" "")
    [ "$result" = "from_env" ]
}

@test "fw_config returns default for unset env var" {
    unset FW_NONEXISTENT_KEY
    result=$(fw_config "NONEXISTENT_KEY" "fallback")
    [ "$result" = "fallback" ]
}

# --- fw_config_int ---

@test "fw_config_int returns valid integer default" {
    unset FW_COUNT
    result=$(fw_config_int "COUNT" 42)
    [ "$result" = "42" ]
}

@test "fw_config_int returns valid integer from env" {
    result=$(FW_COUNT=99 fw_config_int "COUNT" 42)
    [ "$result" = "99" ]
}

@test "fw_config_int rejects non-integer, returns default" {
    result=$(FW_COUNT=banana fw_config_int "COUNT" 42 2>/dev/null)
    [ "$result" = "42" ]
}

@test "fw_config_int emits warning for non-integer" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/config.sh'; FW_COUNT=banana fw_config_int COUNT 42"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"banana"* ]]
}

@test "fw_config_int accepts zero" {
    result=$(FW_COUNT=0 fw_config_int "COUNT" 42)
    [ "$result" = "0" ]
}

@test "fw_config_int rejects negative" {
    result=$(FW_COUNT=-5 fw_config_int "COUNT" 42 2>/dev/null)
    [ "$result" = "42" ]
}

@test "fw_config_int rejects float" {
    result=$(FW_COUNT=3.14 fw_config_int "COUNT" 42 2>/dev/null)
    [ "$result" = "42" ]
}

@test "fw_config_int explicit overrides env" {
    result=$(FW_COUNT=99 fw_config_int "COUNT" 42 77)
    [ "$result" = "77" ]
}

# --- fw_config_list ---

@test "fw_config_list shows FW_ env vars" {
    result=$(FW_TEST_A=1 FW_TEST_B=2 fw_config_list)
    [[ "$result" == *"FW_TEST_A=1"* ]]
    [[ "$result" == *"FW_TEST_B=2"* ]]
}

# --- fw_config_registry ---

@test "fw_config_registry lists known settings" {
    result=$(fw_config_registry)
    [[ "$result" == *"CONTEXT_WINDOW"* ]]
    [[ "$result" == *"DISPATCH_LIMIT"* ]]
    [[ "$result" == *"PORT"* ]]
}

@test "fw_config_registry shows default source when no override" {
    unset FW_CONTEXT_WINDOW
    result=$(fw_config_registry | grep "CONTEXT_WINDOW")
    [[ "$result" == *"|default|"* ]]
}

@test "fw_config_registry shows env source when overridden" {
    result=$(FW_CONTEXT_WINDOW=500000 fw_config_registry | grep "CONTEXT_WINDOW")
    [[ "$result" == *"|env|"* ]]
    [[ "$result" == *"|500000|"* ]]
}

# --- Real settings ---

@test "CONTEXT_WINDOW default is 300000" {
    unset FW_CONTEXT_WINDOW
    result=$(fw_config_int "CONTEXT_WINDOW" 300000)
    [ "$result" = "300000" ]
}

@test "DISPATCH_LIMIT default is 2" {
    unset FW_DISPATCH_LIMIT
    result=$(fw_config_int "DISPATCH_LIMIT" 2)
    [ "$result" = "2" ]
}

@test "FW_CONTEXT_WINDOW override works" {
    result=$(FW_CONTEXT_WINDOW=1000000 fw_config_int "CONTEXT_WINDOW" 300000)
    [ "$result" = "1000000" ]
}

# --- .framework.yaml tier (T-891, T-894) ---

setup_config_file() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_PROJECT_ROOT="$BATS_TMPDIR/fw_config_test_$$"
    mkdir -p "$TEST_PROJECT_ROOT"
    cat > "$TEST_PROJECT_ROOT/.framework.yaml" << 'EOF'
project_name: test-project
version: 1.0.0
PORT: 4000
CONTEXT_WINDOW: 500000
watchtower:
  port: 4001
  theme: dark
EOF
    # Override PROJECT_ROOT for config file lookup
    export PROJECT_ROOT="$TEST_PROJECT_ROOT"
    # Re-source to pick up new PROJECT_ROOT
    _FW_CONFIG_LOADED=""
    source "$FRAMEWORK_ROOT/lib/config.sh"
}

teardown_config_file() {
    rm -rf "$TEST_PROJECT_ROOT" 2>/dev/null || true
}

@test "_fw_config_file_val reads flat key" {
    setup_config_file
    result=$(_fw_config_file_val "PORT")
    teardown_config_file
    [ "$result" = "4000" ]
}

@test "_fw_config_file_val reads dotted key" {
    setup_config_file
    result=$(_fw_config_file_val "watchtower.port")
    teardown_config_file
    [ "$result" = "4001" ]
}

@test "_fw_config_file_val returns 1 for missing key" {
    setup_config_file
    run _fw_config_file_val "NONEXISTENT_KEY"
    teardown_config_file
    [ "$status" -ne 0 ]
}

@test "_fw_config_file_val returns 1 when no config file" {
    export PROJECT_ROOT="/tmp/no_such_dir_$$"
    _FW_CONFIG_LOADED=""
    source "$FRAMEWORK_ROOT/lib/config.sh"
    run _fw_config_file_val "PORT"
    [ "$status" -ne 0 ]
}

@test "fw_config reads from .framework.yaml when no env var" {
    setup_config_file
    unset FW_PORT
    result=$(fw_config "PORT" "3000")
    teardown_config_file
    [ "$result" = "4000" ]
}

@test "fw_config env var takes precedence over .framework.yaml" {
    setup_config_file
    result=$(FW_PORT=5000 fw_config "PORT" "3000")
    teardown_config_file
    [ "$result" = "5000" ]
}

@test "fw_config falls to default when key not in .framework.yaml" {
    setup_config_file
    unset FW_STALE_TASK_DAYS
    result=$(fw_config "STALE_TASK_DAYS" "7")
    teardown_config_file
    [ "$result" = "7" ]
}

@test "fw_config_registry shows source=file for .framework.yaml values" {
    setup_config_file
    unset FW_PORT
    result=$(fw_config_registry | grep "^PORT|")
    teardown_config_file
    [[ "$result" == *"|file|"* ]]
    [[ "$result" == *"|4000|"* ]]
}

@test "fw_config_registry shows source=env over file" {
    setup_config_file
    result=$(FW_PORT=9999 fw_config_registry | grep "^PORT|")
    teardown_config_file
    [[ "$result" == *"|env|"* ]]
    [[ "$result" == *"|9999|"* ]]
}
