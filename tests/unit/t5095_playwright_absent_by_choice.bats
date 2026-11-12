#!/usr/bin/env bats
# T-5095 (GitHub #98 follow-up) — Mehdi: with everything else declared absent, the
# Playwright pip package was still a permanent `fw doctor` WARN. `playwright` is now an
# optional component: listed in ABSENT_COMPONENTS, both Playwright lines (pip package,
# MCP server) read OK "absent by choice"; not listed, they WARN as before.
#
# Playwright is hidden with a module on PYTHONPATH that refuses to import, so the test
# does not depend on whether this host has it installed. The project has no .mcp.json.

bats_require_minimum_version 1.5.0

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/.tasks/completed"
    printf 'project_name: t5095\nversion: 1.0\n' > "$PROJ/.framework.yaml"
    mkdir -p "$TEST_TEMP_DIR/hide/playwright"
    echo 'raise ImportError("hidden by t5095")' > "$TEST_TEMP_DIR/hide/playwright/__init__.py"
}

teardown() { [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"; return 0; }

doctor() {
    env -u FW_ABSENT_COMPONENTS PYTHONPATH="$TEST_TEMP_DIR/hide" PROJECT_ROOT="$PROJ" \
        FRAMEWORK_ROOT="$(ROOT)" "$@" "$(ROOT)/bin/fw" doctor --quick 2>&1
}

@test "the hiding module really makes playwright unimportable" {
    run env PYTHONPATH="$TEST_TEMP_DIR/hide" python3 -c "import playwright"
    [ "$status" -ne 0 ]
}

@test "T-5095: playwright is an optional component" {
    run python3 "$(ROOT)/lib/optional_components.py"
    [[ " $output " == *" playwright "* ]]
}

@test "T-5095: undeclared, the missing pip package still WARNs" {
    run doctor
    [[ "$output" == *"WARN"*"Playwright pip package missing"* ]]
    [[ "$output" != *"Playwright pip package not installed — absent by choice"* ]]
}

@test "T-5095: declared, both Playwright lines read absent by choice" {
    run doctor FW_ABSENT_COMPONENTS="playwright"
    echo "$output" | grep -i playwright >&2
    [[ "$output" == *"Playwright pip package not installed — absent by choice (ABSENT_COMPONENTS)"* ]]
    [[ "$output" == *"Playwright MCP server not installed — absent by choice (ABSENT_COMPONENTS)"* ]]
    [[ "$output" != *"Playwright pip package missing"* ]]
    [[ "$output" != *"Playwright MCP server not in .mcp.json"* ]]
    [[ "$output" != *"not an optional component"* ]]
}
