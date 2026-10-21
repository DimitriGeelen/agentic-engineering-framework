#!/usr/bin/env bats
# T-4326: `fw rail status` must measure the HOST fingerprint with the
# identity-selecting env stripped. A session that already exports
# TERMLINK_IDENTITY_FILE=<project key> (832's rollout) used to resolve the "host"
# key AS the project key, compare the key with itself, and report state: host.
#
# termlink is replaced by a stub on PATH whose fingerprint depends only on the
# identity env, so the legs are deterministic and never mint a real key.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    mkdir -p "$TEST_TEMP_DIR/bin" "$TEST_TEMP_DIR/proj/.context/working"
    : > "$TEST_TEMP_DIR/proj/.framework.yaml"
    cat > "$TEST_TEMP_DIR/bin/termlink" <<'EOF'
#!/usr/bin/env bash
# stub: fingerprint is a function of the identity selectors only
if [ -n "${TERMLINK_IDENTITY_FILE:-}" ]; then
    fp="$(printf '%s' "$TERMLINK_IDENTITY_FILE" | sha256sum | cut -c1-16)"
elif [ -n "${TERMLINK_AGENT_ID:-}" ]; then
    fp="$(printf 'agent:%s' "$TERMLINK_AGENT_ID" | sha256sum | cut -c1-16)"
elif [ -n "${TERMLINK_IDENTITY_DIR:-}" ]; then
    fp="$(printf 'dir:%s' "$TERMLINK_IDENTITY_DIR" | sha256sum | cut -c1-16)"
else
    fp="0000000000000000"
fi
printf '{"fingerprint":"%s"}\n' "$fp"
EOF
    chmod +x "$TEST_TEMP_DIR/bin/termlink"
    KEY="$TEST_TEMP_DIR/proj.key"
    export KEY
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_status() {
    cd "$TEST_TEMP_DIR/proj"
    run env PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$TEST_TEMP_DIR/proj" \
        FW_RAIL_IDENTITY_FILE="$KEY" "$@" "$FRAMEWORK_ROOT/bin/fw" rail status
}

@test "T-4326: exported TERMLINK_IDENTITY_FILE = configured key reads state: project" {
    _status TERMLINK_IDENTITY_FILE="$KEY"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "state:       project"
}

@test "T-4326: exported TERMLINK_AGENT_ID / TERMLINK_IDENTITY_DIR do not stand in for the host" {
    _status TERMLINK_IDENTITY_FILE="$KEY" TERMLINK_AGENT_ID=x TERMLINK_IDENTITY_DIR="$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "state:       project"
}

@test "T-4326: control — no project key configured still reads state: host" {
    cd "$TEST_TEMP_DIR/proj"
    run env -u FW_RAIL_IDENTITY_FILE PATH="$TEST_TEMP_DIR/bin:$PATH" \
        PROJECT_ROOT="$TEST_TEMP_DIR/proj" "$FRAMEWORK_ROOT/bin/fw" rail status
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "state:       host"
}
