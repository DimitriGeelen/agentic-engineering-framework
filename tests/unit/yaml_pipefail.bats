#!/usr/bin/env bats
# T-1557 / L-302 — Regression: foundation YAML/config helpers must not
# silent-kill the calling shell under set -e -o pipefail when the requested
# field/key is absent.
#
# Origin: T-1545 fixed one site (lib/review.sh emit_review). This pins the
# same invariant for the foundation helpers (lib/yaml.sh:get_yaml_field +
# lib/config.sh:_fw_config_file_val) so future callers cannot reintroduce
# the trap by writing bare `var=$(get_yaml_field ...)` assignments.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "get_yaml_field: bare assignment + missing field does not exit 1 under set -e -o pipefail" {
    local file="$TEST_TEMP_DIR/sample.md"
    cat > "$file" <<EOF
---
id: T-1
name: "Test"
---
EOF

    run bash -c "
        set -e -o pipefail
        source '$FRAMEWORK_ROOT/lib/yaml.sh'
        v=\$(get_yaml_field '$file' missing_field)
        echo \"PASS: v='\$v'\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"v=''"* ]]
}

@test "get_yaml_field: returns the value for a present field" {
    local file="$TEST_TEMP_DIR/sample.md"
    cat > "$file" <<EOF
---
id: T-1
status: started-work
name: "Test"
---
EOF

    run bash -c "
        set -e -o pipefail
        source '$FRAMEWORK_ROOT/lib/yaml.sh'
        v=\$(get_yaml_field '$file' status)
        echo \"v=\$v\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"v=started-work"* ]]
}

@test "get_yaml_field: handles double-quoted values" {
    local file="$TEST_TEMP_DIR/sample.md"
    printf 'name: "Quoted Title"\n' > "$file"

    run bash -c "
        set -e -o pipefail
        source '$FRAMEWORK_ROOT/lib/yaml.sh'
        v=\$(get_yaml_field '$file' name)
        echo \"v=\$v\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"v=Quoted Title"* ]]
}

@test "_fw_config_file_val: missing key returns 1 cleanly (does not kill caller under set -e)" {
    local cfg="$TEST_TEMP_DIR/.framework.yaml"
    cat > "$cfg" <<EOF
PORT: 4000
EOF

    # The caller runs with set -e -o pipefail and uses an `if` test (the
    # idiomatic way to consume a function that may return 1). The function
    # itself must not propagate a pipeline-failure exit through bare
    # assignment when the key is absent.
    run bash -c "
        set -e -o pipefail
        export PROJECT_ROOT='$TEST_TEMP_DIR'
        source '$FRAMEWORK_ROOT/lib/config.sh'
        if val=\$(_fw_config_file_val MISSING_KEY); then
            echo 'unexpected: found'
        else
            echo 'expected: not-found'
        fi
        echo 'caller-still-alive'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected: not-found"* ]]
    [[ "$output" == *"caller-still-alive"* ]]
}

@test "_fw_config_file_val: present key returns its value" {
    local cfg="$TEST_TEMP_DIR/.framework.yaml"
    cat > "$cfg" <<EOF
PORT: 4000
EOF

    run bash -c "
        set -e -o pipefail
        export PROJECT_ROOT='$TEST_TEMP_DIR'
        source '$FRAMEWORK_ROOT/lib/config.sh'
        v=\$(_fw_config_file_val PORT)
        echo \"v=\$v\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"v=4000"* ]]
}
