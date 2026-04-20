#!/usr/bin/env bats
# T-1364 (G-053-A): Unit tests for absolute hook paths in .claude/settings.json.
#
# Claude Code resolves hook commands against the session CWD. When CWD drifts
# (test fixtures, subdir navigation), relative paths like "bin/fw hook X"
# cascade into tool-blocks. Fix: emit absolute paths at init/upgrade time.
# $target_dir is canonicalized via `cd && pwd` in both entry points.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: assert every hook command in settings.json is absolute (starts with /)
assert_all_hooks_absolute() {
    local settings_file="$1"
    python3 -c "
import json, sys
with open('$settings_file') as f:
    data = json.load(f)
bad = []
for event, entries in data.get('hooks', {}).items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            # Extract the binary path (first token)
            bin_path = cmd.split()[0] if cmd else ''
            if bin_path and not bin_path.startswith('/'):
                bad.append(f'{event}: {cmd}')
if bad:
    print('RELATIVE HOOK COMMANDS FOUND:')
    for b in bad:
        print(f'  {b}')
    sys.exit(1)
print(f'OK — {sum(len(v) for v in data[\"hooks\"].values())} hooks, all absolute')
"
}

@test "hook paths: framework's own settings.json has only absolute fw paths" {
    run assert_all_hooks_absolute "$FRAMEWORK_ROOT/.claude/settings.json"
    [ "$status" -eq 0 ]
}

@test "hook paths: generate_claude_code_config for framework-mode emits absolute paths" {
    # Build a minimal framework fixture
    local fake_fw="$TEST_TEMP_DIR/fw-repo"
    mkdir -p "$fake_fw/bin" "$fake_fw/agents"
    touch "$fake_fw/FRAMEWORK.md"
    cp "$FRAMEWORK_ROOT/bin/fw" "$fake_fw/bin/fw"

    # Source init.sh and invoke the generator
    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && generate_claude_code_config '$fake_fw'" >/dev/null

    run assert_all_hooks_absolute "$fake_fw/.claude/settings.json"
    [ "$status" -eq 0 ]

    # Also: every fw path should start with $fake_fw/bin/fw (framework mode)
    run grep -c "\"command\": \"$fake_fw/bin/fw hook" "$fake_fw/.claude/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "hook paths: generate_claude_code_config for consumer-mode emits absolute vendored paths" {
    local consumer="$TEST_TEMP_DIR/consumer"
    mkdir -p "$consumer/.agentic-framework/bin" "$consumer/.agentic-framework/agents"
    touch "$consumer/.agentic-framework/FRAMEWORK.md"
    cp "$FRAMEWORK_ROOT/bin/fw" "$consumer/.agentic-framework/bin/fw"
    # Note: no $consumer/bin/fw — so consumer mode is selected

    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && generate_claude_code_config '$consumer'" >/dev/null

    run assert_all_hooks_absolute "$consumer/.claude/settings.json"
    [ "$status" -eq 0 ]

    # Consumer mode uses .agentic-framework/bin/fw — absolute form
    run grep -c "\"command\": \"$consumer/.agentic-framework/bin/fw hook" "$consumer/.claude/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "hook paths: no relative bin/fw remains in generated settings.json" {
    local fake="$TEST_TEMP_DIR/p"
    mkdir -p "$fake/.agentic-framework/bin" "$fake/.agentic-framework/agents"
    touch "$fake/.agentic-framework/FRAMEWORK.md"
    cp "$FRAMEWORK_ROOT/bin/fw" "$fake/.agentic-framework/bin/fw"

    bash -c "source '$FRAMEWORK_ROOT/lib/init.sh' && generate_claude_code_config '$fake'" >/dev/null

    # Assert no relative "bin/fw hook" or ".agentic-framework/bin/fw hook" (unprefixed)
    ! grep -qE '"command": *"bin/fw hook' "$fake/.claude/settings.json"
    ! grep -qE '"command": *"\.agentic-framework/bin/fw hook' "$fake/.claude/settings.json"
}
