#!/usr/bin/env bats
# T-5123 — `fw termlink check` completes when no hub is reachable.
#
# BEFORE: agents/termlink/termlink.sh declared `local hub_pid hub_dir cfg_dir`
# without initialising them. `hub_dir` is assigned only inside
#   if [ -n "$hub_pid" ] && [ -r "/proc/$hub_pid/environ" ]
# so when no hub process is found — or its environ is unreadable — it stayed
# DECLARED BUT UNSET. The script runs under `set -u`, so the first dereference
# (`[ -n "$hub_dir" ]`, inside the `if [ -f "$mcp" ]` branch) aborted the whole
# function with `hub_dir: unbound variable`.
#
# The failure fired exactly when no hub was reachable — which is when an agent
# runs this command to find out why. On 2026-11-13 it masked the real finding
# underneath it ("agent-chat-arc is NOT on the store the CLI resolves").
#
# The subject here is the REAL script, run from a mirrored tree so its
# SCRIPT_DIR/../.. resolution still finds lib/. The control leg runs the same
# script with the initialisers stripped back out, so a pass proves the test can
# still SEE the bug rather than merely that nothing crashed today.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJECT_ROOT="$TEST_TEMP_DIR"
    export PROJECT_ROOT
    guard_project_root

    mkdir -p "$TEST_TEMP_DIR/agents/termlink" "$TEST_TEMP_DIR/stub"
    ln -s "$FRAMEWORK_ROOT/lib" "$TEST_TEMP_DIR/lib"

    # A pgrep that finds no hub and EXITS 0. Exiting non-zero instead aborts the
    # `hub_pid=$(pgrep … | head -1)` assignment under `set -euo pipefail` before
    # the bug site is ever reached — an earlier draft of this test "passed"
    # against the broken source for exactly that reason.
    printf '#!/bin/sh\nexit 0\n' > "$TEST_TEMP_DIR/stub/pgrep"
    chmod +x "$TEST_TEMP_DIR/stub/pgrep"

    # A local `termlink` stub, AHEAD of the suite's tripwire on PATH. The tripwire
    # returns nothing for `--version`, which sends cmd_check down its
    # "version failed" branch and `return 1` — before _check_hub_store_parity,
    # where the bug lives. That is how the first draft of this file reported a
    # green subject leg while exercising nothing. This stub answers --version and
    # `channel list` locally and contacts nothing, so the G-115 reason for the
    # tripwire (never reach the host hub or outbound queue) still holds.
    cat > "$TEST_TEMP_DIR/stub/termlink" <<'STUB'
#!/bin/sh
case "$1" in
  --version|-V) echo "termlink 0.0.0-t5123-stub"; exit 0 ;;
esac
exit 0
STUB
    chmod +x "$TEST_TEMP_DIR/stub/termlink"

    # The dereference lives inside `if [ -f "$mcp" ]`, so the fixture needs an
    # .mcp.json. An empty env block leaves cfg_dir empty, which selects the
    # `[ -z "$cfg_dir" ]` branch and its `[ -n "$hub_dir" ]` — the first read.
    printf '%s\n' '{"mcpServers":{"termlink":{"env":{}}}}' > "$TEST_TEMP_DIR/.mcp.json"

    cp "$FRAMEWORK_ROOT/agents/termlink/termlink.sh" \
       "$TEST_TEMP_DIR/agents/termlink/fixed.sh"
    sed 's/local hub_pid="" hub_dir="" cfg_dir=""/local hub_pid hub_dir cfg_dir/' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh" \
        > "$TEST_TEMP_DIR/agents/termlink/broken.sh"
    chmod +x "$TEST_TEMP_DIR/agents/termlink"/fixed.sh "$TEST_TEMP_DIR/agents/termlink"/broken.sh
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "$TEST_TEMP_DIR" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

@test "T-5123: termlink check completes with no hub reachable" {
    run env PATH="$TEST_TEMP_DIR/stub:$PATH" PROJECT_ROOT="$TEST_TEMP_DIR" \
        bash "$TEST_TEMP_DIR/agents/termlink/fixed.sh" check
    # Positive evidence that the bug site was REACHED, not merely that nothing
    # crashed: this WARN is emitted inside the same `if [ -f "$mcp" ]` branch that
    # holds the first `[ -n "$hub_dir" ]` read. Asserting only the absence of the
    # abort passes just as well when the function returned early.
    [[ "$output" == *"sets no TERMLINK_RUNTIME_DIR"* ]]
    [[ "$output" != *"unbound variable"* ]]
    [ "$status" -eq 0 ]
}

@test "T-5123 control: stripping the initialisers brings the abort back" {
    run env PATH="$TEST_TEMP_DIR/stub:$PATH" PROJECT_ROOT="$TEST_TEMP_DIR" \
        bash "$TEST_TEMP_DIR/agents/termlink/broken.sh" check
    [[ "$output" == *"hub_dir: unbound variable"* ]]
}

@test "T-5123: the shipped source initialises hub_pid, hub_dir and cfg_dir" {
    run grep -c 'local hub_pid="" hub_dir="" cfg_dir=""' \
        "$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}
