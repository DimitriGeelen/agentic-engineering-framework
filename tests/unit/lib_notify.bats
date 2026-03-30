#!/usr/bin/env bats
# Unit tests for lib/notify.sh
#
# Tests fw_notify() — push notification helper

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/notify.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "notify: fw_notify returns 0 when disabled (default)" {
    unset NTFY_ENABLED
    run fw_notify "Test Title" "Test Message"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "notify: fw_notify returns 0 with empty title when disabled" {
    unset NTFY_ENABLED
    run fw_notify "" ""
    [ "$status" -eq 0 ]
}

@test "notify: fw_notify returns 0 with empty title when enabled" {
    export NTFY_ENABLED=true
    run fw_notify "" "message"
    [ "$status" -eq 0 ]
}

@test "notify: fw_notify reads config from notify-config.yaml" {
    unset NTFY_ENABLED
    mkdir -p "$TEST_TEMP_DIR/.context"
    echo "enabled: false" > "$TEST_TEMP_DIR/.context/notify-config.yaml"
    run fw_notify "Test" "Message"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "notify: fw_notify skips when dispatcher not found" {
    export NTFY_ENABLED=true
    export SKILLS_DISPATCHER="/nonexistent/dispatcher.py"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    run fw_notify "Test" "Message"
    [ "$status" -eq 0 ]
}

@test "notify: _SKILLS_DISPATCHER has default path" {
    unset SKILLS_DISPATCHER
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    [[ "$_SKILLS_DISPATCHER" == *"alert_dispatcher.py"* ]]
}

@test "notify: _SKILLS_DISPATCHER respects env override" {
    export SKILLS_DISPATCHER="/custom/path/dispatcher.py"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    [ "$_SKILLS_DISPATCHER" = "/custom/path/dispatcher.py" ]
}
