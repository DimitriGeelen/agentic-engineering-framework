#!/usr/bin/env bats
# Integration tests for fw plugin-audit subcommand
#
# T-4618: every test owns its HOME. plugin-audit reads
# $HOME/.claude/settings.json (enabledPlugins) and the plugin cache under
# $HOME/.claude/plugins, so without a fixture the tests audited the operator's
# live plugins and failed on any host without them.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"

    # One enabled plugin with a task-aware and a task-silent skill, plus one
    # enabled plugin that is not installed and one that is disabled.
    mkdir -p "$HOME/.claude"
    cat > "$HOME/.claude/settings.json" << 'JSON'
{"enabledPlugins": {"fixture-plugin@claude-plugins-official": true,
                    "missing-plugin@claude-plugins-official": true,
                    "disabled-plugin@claude-plugins-official": false}}
JSON
    local pdir="$HOME/.claude/plugins/cache/claude-plugins-official/fixture-plugin/1.0.0"
    mkdir -p "$pdir/skills/aware" "$pdir/skills/silent"
    printf '%s\n' "Run fw work-on before editing." > "$pdir/skills/aware/SKILL.md"
    printf '%s\n' "Formats a table." > "$pdir/skills/silent/SKILL.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw plugin-audit: runs audit" {
    run "$FW" plugin-audit
    [ "$status" -eq 0 ]
    [[ "$output" == *"Plugin Task-Awareness Audit"* ]]
    [[ "$output" == *"fixture-plugin"*"2 files"* ]]
    [[ "$output" == *"missing-plugin"*"not installed"* ]]
    [[ "$output" != *"disabled-plugin"* ]]
}

@test "fw plugin-audit: shows summary counts" {
    run "$FW" plugin-audit
    [ "$status" -eq 0 ]
    [[ "$output" == *"TASK-AWARE:"*"1"* ]]
    [[ "$output" == *"TASK-SILENT:    1"* ]]
    [[ "$output" == *"TASK-BYPASSING:"*"0"* ]]
}

@test "fw plugin-audit: no settings.json reports no enabled plugins" {
    rm -f "$HOME/.claude/settings.json"
    run "$FW" plugin-audit
    [ "$status" -eq 0 ]
    [[ "$output" == *"No enabled plugins found"* ]]
}
