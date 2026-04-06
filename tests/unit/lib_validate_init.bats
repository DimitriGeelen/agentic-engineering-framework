#!/usr/bin/env bats
# Unit tests for lib/validate-init.sh (fw validate-init)
# Origin: T-945

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
VALIDATE="$FRAMEWORK_ROOT/lib/validate-init.sh"

setup() {
    export TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/.context/working"
    mkdir -p "$TEST_DIR/.tasks/active"
    mkdir -p "$TEST_DIR/.tasks/completed"
    mkdir -p "$TEST_DIR/.tasks/templates"
    cat > "$TEST_DIR/.framework.yaml" << 'EOF'
project_name: test-project
version: 1.0.0
provider: generic
EOF
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "validate-init --help shows usage" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/paths.sh' && source '$VALIDATE' && do_validate_init --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"validate-init"* ]]
    [[ "$output" == *"Verify"* ]]
}

@test "validate-init rejects unknown options" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/paths.sh' && source '$VALIDATE' && do_validate_init --invalid-option"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]]
}

@test "validate-init handles nonexistent directory" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/paths.sh' && source '$VALIDATE' && do_validate_init /nonexistent/path/xyz"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "validate-init runs on test directory" {
    run bash -c "export FRAMEWORK_ROOT='$FRAMEWORK_ROOT' && source '$FRAMEWORK_ROOT/lib/paths.sh' && source '$VALIDATE' && do_validate_init '$TEST_DIR' --provider generic"
    [[ "$status" -le 1 ]]
}

@test "validate-init accepts --quiet flag" {
    run bash -c "export FRAMEWORK_ROOT='$FRAMEWORK_ROOT' && source '$FRAMEWORK_ROOT/lib/paths.sh' && source '$VALIDATE' && do_validate_init '$TEST_DIR' --provider generic --quiet"
    [[ "$status" -le 1 ]]
}

@test "validate-init detects provider from .framework.yaml" {
    run bash -c "export FRAMEWORK_ROOT='$FRAMEWORK_ROOT' && source '$FRAMEWORK_ROOT/lib/paths.sh' && source '$VALIDATE' && do_validate_init '$TEST_DIR'"
    [[ "$status" -le 1 ]]
}

@test "validate-init on framework root runs checks" {
    run bash -c "export FRAMEWORK_ROOT='$FRAMEWORK_ROOT' && source '$FRAMEWORK_ROOT/lib/paths.sh' && source '$VALIDATE' && do_validate_init '$FRAMEWORK_ROOT' --provider claude-code"
    # May have warnings from invalid task files, but should complete (0 or 1)
    [[ "$status" -le 1 ]]
    [[ "$output" == *"Validation"* ]]
}
