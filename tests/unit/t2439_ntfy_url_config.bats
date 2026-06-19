#!/usr/bin/env bats
# T-2439: configurable ntfy server URL via fw config (portable, no host-local fallback).
#
# The framework runs the ntfy dispatcher LOCALLY on whichever host calls fw_notify,
# and each host's dispatcher defaults to its own ntfy server. Inferring the target
# from one host's config — or letting it silently fall back to a host's local ntfy —
# shipped pushes to a decommissioned server (the .107 incident). Fix: make the ntfy
# server an explicit framework config key (NTFY_URL), 4-tier resolved, exported to
# the dispatcher so the chosen instance is unambiguous and visible.
#
# Surfaces:
#   NTFY_URL registered in lib/config.sh + web/blueprints/config.py   — t1, t2 (static)
#   fw_notify_url: unset→empty, FW_NTFY_URL env→value, yaml→value      — t3,t4,t5 (behavioral)
#   fw_notify exports NTFY_URL to the dispatcher when configured       — t6,t7 (behavioral)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    PROJECT_ROOT=$(create_test_project "$TEST_TEMP_DIR/project")
    export PROJECT_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ── Static: NTFY_URL registered in both registry mirrors ──────────────────

@test "t2439 t1: NTFY_URL is in lib/config.sh FW_CONFIG_REGISTRY (empty default)" {
    grep -qE '"NTFY_URL\|\|' "$FRAMEWORK_ROOT/lib/config.sh"
}

@test "t2439 t2: NTFY_URL is mirrored in web/blueprints/config.py SETTINGS" {
    grep -qE '\("NTFY_URL", "", ' "$FRAMEWORK_ROOT/web/blueprints/config.py"
}

# ── Behavioral: fw_notify_url resolution (4-tier) ─────────────────────────

@test "t2439 t3: fw_notify_url is empty when unset (dispatcher default)" {
    run bash -c "source '$FRAMEWORK_ROOT/lib/config.sh'; source '$FRAMEWORK_ROOT/lib/notify.sh'; fw_notify_url"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "t2439 t4: fw_notify_url resolves FW_NTFY_URL env override" {
    run bash -c "export FW_NTFY_URL='https://ntfy.example.com'; source '$FRAMEWORK_ROOT/lib/config.sh'; source '$FRAMEWORK_ROOT/lib/notify.sh'; fw_notify_url"
    [ "$status" -eq 0 ]
    [ "$output" = "https://ntfy.example.com" ]
}

@test "t2439 t5: fw_notify_url resolves NTFY_URL from .framework.yaml" {
    echo "NTFY_URL: https://ntfy.fromfile" >> "$PROJECT_ROOT/.framework.yaml"
    run bash -c "cd '$PROJECT_ROOT'; export PROJECT_ROOT='$PROJECT_ROOT'; source '$FRAMEWORK_ROOT/lib/config.sh'; source '$FRAMEWORK_ROOT/lib/notify.sh'; fw_notify_url"
    [ "$status" -eq 0 ]
    [ "$output" = "https://ntfy.fromfile" ]
}

# ── Behavioral: fw_notify exports the configured URL to the dispatcher ─────

_install_url_capture_dispatcher() {
    CAP="$TEST_TEMP_DIR/captured-ntfy-url.txt"
    rm -f "$CAP"
    FAKE="$TEST_TEMP_DIR/fake_dispatcher.py"
    cat > "$FAKE" <<PYEOF
import os
with open("$CAP", "w") as f:
    f.write(os.environ.get("NTFY_URL", "<unset>"))
PYEOF
    export SKILLS_DISPATCHER="$FAKE"
}

@test "t2439 t6: fw_notify exports configured NTFY_URL to the dispatcher env" {
    export NTFY_ENABLED=true
    export FW_NTFY_URL="https://ntfy.chosen-instance"
    _install_url_capture_dispatcher
    source "$FRAMEWORK_ROOT/lib/config.sh"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    fw_notify "Title" "Body" "manual" "framework"
    wait
    [ -f "$CAP" ]
    [ "$(cat "$CAP")" = "https://ntfy.chosen-instance" ]
}

@test "t2439 t7: fw_notify leaves NTFY_URL to dispatcher default when unconfigured" {
    export NTFY_ENABLED=true
    unset FW_NTFY_URL
    _install_url_capture_dispatcher
    source "$FRAMEWORK_ROOT/lib/config.sh"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    fw_notify "Title" "Body" "manual" "framework"
    wait
    [ -f "$CAP" ]
    # No NTFY_URL exported by the framework → dispatcher sees it unset (uses its default)
    [ "$(cat "$CAP")" = "<unset>" ]
}
