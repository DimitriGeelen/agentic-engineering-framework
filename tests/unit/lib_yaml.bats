#!/usr/bin/env bats
# Unit tests for lib/yaml.sh
#
# Tests get_yaml_field() — YAML frontmatter field extraction

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT

    # Reset guard to allow re-sourcing
    unset _FW_YAML_LOADED
    source "$FRAMEWORK_ROOT/lib/yaml.sh"

    # Create test YAML file
    cat > "$TEST_TEMP_DIR/test.md" << 'EOF'
---
id: T-042
name: "Test Task"
status: started-work
workflow_type: build
horizon: now
description: A simple description
tags: [test, unit]
created: 2026-03-30T10:00:00Z
unquoted_field: hello world
single_quoted: 'single value'
---
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "yaml: extracts quoted string field" {
    result=$(get_yaml_field "$TEST_TEMP_DIR/test.md" "name")
    [ "$result" = "Test Task" ]
}

@test "yaml: extracts unquoted field" {
    result=$(get_yaml_field "$TEST_TEMP_DIR/test.md" "status")
    [ "$result" = "started-work" ]
}

@test "yaml: extracts field with colon in value" {
    result=$(get_yaml_field "$TEST_TEMP_DIR/test.md" "created")
    [ "$result" = "2026-03-30T10:00:00Z" ]
}

@test "yaml: extracts array-style field" {
    result=$(get_yaml_field "$TEST_TEMP_DIR/test.md" "tags")
    [ "$result" = "[test, unit]" ]
}

@test "yaml: extracts unquoted multi-word value" {
    result=$(get_yaml_field "$TEST_TEMP_DIR/test.md" "unquoted_field")
    [ "$result" = "hello world" ]
}

@test "yaml: extracts single-quoted value" {
    result=$(get_yaml_field "$TEST_TEMP_DIR/test.md" "single_quoted")
    [ "$result" = "single value" ]
}

@test "yaml: returns empty for nonexistent field" {
    result=$(get_yaml_field "$TEST_TEMP_DIR/test.md" "nonexistent")
    [ -z "$result" ]
}

@test "yaml: returns empty for nonexistent file" {
    result=$(get_yaml_field "$TEST_TEMP_DIR/missing.md" "name")
    [ -z "$result" ]
}
