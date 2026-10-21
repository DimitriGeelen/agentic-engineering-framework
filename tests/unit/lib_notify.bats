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

# ── T-3866: a dispatcher that exists but is a package module ─────────────────
# Same shape as skills-manager's alert_dispatcher.py: relative import, no
# __main__, a dispatch_alert() API. `python3 <file>` cannot run it.
_make_pkg_dispatcher() {
    local root="$TEST_TEMP_DIR/sm"
    mkdir -p "$root/skills/alerts"
    : > "$root/skills/__init__.py"
    : > "$root/skills/alerts/__init__.py"
    echo 'SINK = "'"$TEST_TEMP_DIR"'/sent.log"' > "$root/skills/alerts/alert_config.py"
    cat > "$root/skills/alerts/alert_dispatcher.py" <<'PY'
import os
from .alert_config import SINK
def dispatch_alert(trigger, title, message, context=None, level=None):
    with open(SINK, "a") as f:
        f.write(f"{trigger}|{title}|{message}|{os.environ.get('NTFY_URL','')}\n")
    return {"id": "x"}
PY
    echo "$root/skills/alerts/alert_dispatcher.py"
}

@test "T-3866: the old script invocation cannot run a package dispatcher (control)" {
    d=$(_make_pkg_dispatcher)
    run python3 "$d" --trigger manual --title t --message m
    [ "$status" -ne 0 ]
    [[ "$output" == *"relative import"* ]]
}

@test "T-3866: fw_notify_send delivers through a package dispatcher, exit 0" {
    export SKILLS_DISPATCHER="$(_make_pkg_dispatcher)"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    run fw_notify_send manual "Hello" "Body"
    [ "$status" -eq 0 ]
    grep -q "^manual|Hello|Body|" "$TEST_TEMP_DIR/sent.log"
}

@test "T-3866: fw_notify_send passes NTFY_URL from config to the dispatcher" {
    export SKILLS_DISPATCHER="$(_make_pkg_dispatcher)"
    export FW_NTFY_URL="https://ntfy.example.test"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    run fw_notify_send manual "Hello" "Body"
    [ "$status" -eq 0 ]
    grep -q "|https://ntfy.example.test$" "$TEST_TEMP_DIR/sent.log"
}

@test "T-3866: fw_notify (background) delivers and logs nothing on success" {
    export SKILLS_DISPATCHER="$(_make_pkg_dispatcher)"
    export NTFY_ENABLED=true
    mkdir -p "$TEST_TEMP_DIR/.context"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    fw_notify "BgTitle" "BgBody"
    wait
    grep -q "^manual|BgTitle|BgBody|" "$TEST_TEMP_DIR/sent.log"
}

@test "T-3866: a broken dispatcher fails fw_notify_send and its reason reaches notify.log" {
    d=$(_make_pkg_dispatcher)
    rm "$(dirname "$d")/alert_config.py"
    export SKILLS_DISPATCHER="$d"
    export NTFY_ENABLED=true
    mkdir -p "$TEST_TEMP_DIR/.context"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    run fw_notify_send manual "T" "M"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not importable"* ]]
    fw_notify "T" "M"
    wait
    grep -q "not importable" "$TEST_TEMP_DIR/.context/working/notify.log"
}

@test "T-3866: fw_notify_check passes on an importable dispatcher, fails without dispatch_alert" {
    d=$(_make_pkg_dispatcher)
    export SKILLS_DISPATCHER="$d"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    run fw_notify_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"skills.alerts.alert_dispatcher"* ]]
    echo 'from .alert_config import SINK' > "$d"
    run fw_notify_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"no dispatch_alert"* ]]
    [ ! -f "$TEST_TEMP_DIR/sent.log" ]
}

@test "T-3866: doctor check WARNs only when enabled and the dispatcher cannot import" {
    export SKILLS_DISPATCHER="/nonexistent/skills/alerts/alert_dispatcher.py"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    unset NTFY_ENABLED
    warnings=0
    run fw_notify_doctor_check
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    export NTFY_ENABLED=true
    warnings=0
    fw_notify_doctor_check > "$TEST_TEMP_DIR/doc.out"
    grep -q "WARN" "$TEST_TEMP_DIR/doc.out"
    [ "$warnings" -eq 1 ]
    export SKILLS_DISPATCHER="$(_make_pkg_dispatcher)"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    warnings=0
    fw_notify_doctor_check > "$TEST_TEMP_DIR/doc.out"
    grep -q "OK" "$TEST_TEMP_DIR/doc.out"
    [ "$warnings" -eq 0 ]
}

@test "T-3866: fw notify test fails with the dispatcher's reason instead of printing sent" {
    d=$(_make_pkg_dispatcher)
    rm "$(dirname "$d")/alert_config.py"
    mkdir -p "$TEST_TEMP_DIR/.context"
    echo "enabled: true" > "$TEST_TEMP_DIR/.context/notify-config.yaml"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed"
    echo "project_name: notify-fixture" > "$TEST_TEMP_DIR/.framework.yaml"
    cd "$TEST_TEMP_DIR"
    SKILLS_DISPATCHER="$d" PROJECT_ROOT="$TEST_TEMP_DIR" run "$FRAMEWORK_ROOT/bin/fw" notify test
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
    [[ "$output" != *"dispatched"* ]] || false
}
