#!/usr/bin/env bats
# Integration tests for agents/context/check-fabric-new-file.sh
#
# PostToolUse hook that emits advisory when new source files are created
# that match watch-patterns.yaml but aren't registered in .fabric/components/.
# Exit code: always 0 (advisory only, never blocks)

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-fabric-new-file.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.fabric/components"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: create watch-patterns.yaml with given globs
write_watch_patterns() {
    cat > "$PROJECT_ROOT/.fabric/watch-patterns.yaml" <<EOF
patterns:
$(for g in "$@"; do echo "  - glob: \"$g\""; done)
EOF
}

# Helper: run the hook with a given file_path
run_fabric_hook() {
    local file_path="$1"
    local json="{\"tool_name\": \"Write\", \"tool_input\": {\"file_path\": \"$file_path\"}}"
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
}

@test "silent: non-Write tool is ignored" {
    write_watch_patterns "agents/**/*.sh"
    local json='{"tool_name": "Read", "tool_input": {"file_path": "/some/file.py"}}'
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent: file in skip prefix (.context/) is ignored" {
    write_watch_patterns "**/*.yaml"
    run_fabric_hook "$PROJECT_ROOT/.context/working/session.yaml"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent: file in skip prefix (.tasks/) is ignored" {
    write_watch_patterns "**/*.md"
    run_fabric_hook "$PROJECT_ROOT/.tasks/active/T-001-test.md"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent: no watch-patterns.yaml file exits silently" {
    rm -f "$PROJECT_ROOT/.fabric/watch-patterns.yaml"
    run_fabric_hook "$PROJECT_ROOT/agents/new-script.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent: file doesn't match any pattern" {
    write_watch_patterns "agents/**/*.sh"
    run_fabric_hook "$PROJECT_ROOT/docs/readme.md"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "advisory: new file matching pattern emits reminder" {
    write_watch_patterns "agents/**/*.sh"
    run_fabric_hook "$PROJECT_ROOT/agents/new/handler.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw fabric register"* ]]
}

@test "silent: file already registered in fabric" {
    write_watch_patterns "agents/**/*.sh"
    # Create a component card for the file
    cat > "$PROJECT_ROOT/.fabric/components/handler.yaml" <<EOF
id: C-999
name: handler
type: script
location: agents/new/handler.sh
EOF
    run_fabric_hook "$PROJECT_ROOT/agents/new/handler.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "never blocks: exit code is always 0" {
    write_watch_patterns "**/*.sh"
    run_fabric_hook "$PROJECT_ROOT/bin/new-command.sh"
    [ "$status" -eq 0 ]
}
