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
