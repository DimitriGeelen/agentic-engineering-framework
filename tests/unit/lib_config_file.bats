#!/usr/bin/env bats
# Unit tests for lib/config-file.sh — fw config set/get/list
# Origin: T-896

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_DIR="$BATS_TMPDIR/fw_config_file_test_$$"
    mkdir -p "$TEST_DIR"
    export PROJECT_ROOT="$TEST_DIR"
    export _config_yaml="$TEST_DIR/.framework.yaml"

    # Create a minimal .framework.yaml
    cat > "$_config_yaml" << 'EOF'
project_name: test-project
version: 1.0.0
provider: claude-code
EOF

    # Source the config-file library
    _FW_CONFIG_FILE_LOADED=""
    source "$FRAMEWORK_ROOT/lib/config-file.sh"
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- _config_set ---

@test "config set creates flat key" {
    _config_set "PORT" "4000"
    result=$(_config_get "PORT")
    [ "$result" = "4000" ]
}

@test "config set creates dotted key" {
    _config_set "watchtower.port" "4001"
    result=$(_config_get "watchtower.port")
    [ "$result" = "4001" ]
}

@test "config set converts integer" {
    _config_set "PORT" "3000"
    # Verify it was stored as integer (no quotes in YAML)
    result=$(python3 -c "
import yaml
with open('$_config_yaml') as f:
    d = yaml.safe_load(f)
print(type(d['PORT']).__name__)
")
    [ "$result" = "int" ]
}

@test "config set converts boolean true" {
    _config_set "debug" "true"
    result=$(python3 -c "
import yaml
with open('$_config_yaml') as f:
    d = yaml.safe_load(f)
print(type(d['debug']).__name__)
")
    [ "$result" = "bool" ]
}

@test "config set preserves string values" {
    _config_set "project_name" "my-app"
    result=$(_config_get "project_name")
    [ "$result" = "my-app" ]
}

@test "config set overwrites existing value" {
    _config_set "PORT" "3000"
    _config_set "PORT" "4000"
    result=$(_config_get "PORT")
    [ "$result" = "4000" ]
}

# --- _config_get ---

@test "config get reads existing flat key" {
    result=$(_config_get "project_name")
    [ "$result" = "test-project" ]
}

@test "config get exits 1 for missing key" {
    run _config_get "NONEXISTENT"
    [ "$status" -ne 0 ]
}

@test "config get reads dotted key" {
    _config_set "watchtower.theme" "dark"
    result=$(_config_get "watchtower.theme")
    [ "$result" = "dark" ]
}

# --- _config_list ---

@test "config list shows project_name" {
    run _config_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"project_name"* ]]
    [[ "$output" == *"test-project"* ]]
}

@test "config list shows custom settings after set" {
    _config_set "PORT" "4000"
    run _config_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"PORT"* ]]
    [[ "$output" == *"4000"* ]]
}

# --- Error handling ---

@test "config set fails without key" {
    run _config_set "" "value"
    [ "$status" -ne 0 ]
}

@test "config set fails without value" {
    run _config_set "key" ""
    [ "$status" -ne 0 ]
}

@test "config get fails without key" {
    run _config_get ""
    [ "$status" -ne 0 ]
}

# --- do_config routing ---

@test "do_config routes to set" {
    do_config set "PORT" "5000"
    result=$(_config_get "PORT")
    [ "$result" = "5000" ]
}

@test "do_config routes to get" {
    _config_set "PORT" "5000"
    run do_config get "PORT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"5000"* ]]
}

@test "do_config help exits 0" {
    run do_config help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw config"* ]]
}

# --- Validation (T-907) ---

@test "config set warns for non-numeric known integer setting" {
    run bash -c "
        export PROJECT_ROOT='$TEST_DIR'
        _FW_CONFIG_FILE_LOADED=''
        export _config_yaml='$TEST_DIR/.framework.yaml'
        echo 'project_name: test' > '$TEST_DIR/.framework.yaml'
        source '$FRAMEWORK_ROOT/lib/config-file.sh'
        _config_set PORT banana 2>&1
    "
    [[ "$output" == *"WARNING"* ]]
}

@test "config set no warning for numeric known setting" {
    run bash -c "
        export PROJECT_ROOT='$TEST_DIR'
        _FW_CONFIG_FILE_LOADED=''
        export _config_yaml='$TEST_DIR/.framework.yaml'
        echo 'project_name: test' > '$TEST_DIR/.framework.yaml'
        source '$FRAMEWORK_ROOT/lib/config-file.sh'
        _config_set PORT 4000 2>&1
    "
    [[ "$output" != *"WARNING"* ]]
}
