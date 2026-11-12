#!/usr/bin/env bats
# T-5090 (GitHub #110) — `mcp` and `cryptography` were imported by shipped code but named in
# no requirements file, so an environment built from web/requirements.txt had a dead `fw`
# MCP server ("connection closed") and a 500 on /settings/. Both are declared now, and the
# MCP server started without `mcp` prints what to install instead of a traceback.
#
# `mcp` is hidden with a package on PYTHONPATH that refuses to import, so the test does not
# depend on what this host has installed.

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/hide/mcp"
    echo 'raise ImportError("hidden by t5090")' > "$TEST_TEMP_DIR/hide/mcp/__init__.py"
}

teardown() { [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"; return 0; }

@test "T-5090: web/requirements.txt declares cryptography and mcp, each with its reason" {
    grep -qE '^cryptography>=[0-9.]+ +# .*secrets_store' "$(ROOT)/web/requirements.txt"
    grep -qE '^mcp>=[0-9.]+ +# .*framework_mcp_server' "$(ROOT)/web/requirements.txt"
}

@test "T-5090: every top-level import in the two files is declared" {
    grep -q '^from cryptography' "$(ROOT)/web/secrets_store.py"
    grep -q 'from mcp\.' "$(ROOT)/agents/mcp/framework_mcp_server.py"
}

@test "T-5090: without mcp the server names the package and how to install it, no traceback" {
    run env PYTHONPATH="$TEST_TEMP_DIR/hide" python3 "$(ROOT)/agents/mcp/framework_mcp_server.py" </dev/null
    [ "$status" -eq 3 ]
    [[ "$output" == *"the Python package 'mcp' is missing"* ]]
    [[ "$output" == *"-m pip install 'mcp>=1.0'"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "T-5090: imported as a module without mcp, the ImportError is not swallowed" {
    run env PYTHONPATH="$TEST_TEMP_DIR/hide:$(ROOT)/agents/mcp" python3 -c "import framework_mcp_server"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ImportError"* ]]
}

@test "T-5090: with mcp present the server module still imports" {
    python3 -c "import mcp" 2>/dev/null || skip "mcp not installed on this host"
    run env PYTHONPATH="$(ROOT)/agents/mcp" python3 -c "import framework_mcp_server; print('ok')"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}
