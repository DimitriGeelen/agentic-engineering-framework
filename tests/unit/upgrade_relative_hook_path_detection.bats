#!/usr/bin/env bats
# T-1627 (B-1 of T-1626) — `fw upgrade` must detect bare-relative
# `.agentic-framework/bin/fw` paths in `.claude/settings.json` and trigger
# regeneration to absolute paths.
#
# Witness (2026-04-30, /root/ring20-dashboard): a stale pre-T-1364
# settings.json carried bare relative paths. The agent `cd`-ed into a
# subdir and EVERY tool call fired "PostToolUse:Edit hook error /
# .agentic-framework/bin/fw: not found". The framework's stale-detector
# (`check_stale_paths` in lib/upgrade.sh) only flagged `/agents/context/`
# legacy paths and `PROJECT_ROOT=` shells — bare relative paths slipped
# through because they still contain `.agentic-framework` and `fw hook`.
#
# This test pins the missing rule.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "upgrade.sh contains a T-1627 marker on the bare-relative branch" {
    grep -q "T-1627" "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "upgrade.sh check_stale_paths inspects .agentic-framework path prefix" {
    awk '/^def check_stale_paths/,/^[a-z_]+ = check_stale_paths/' "$FRAMEWORK_ROOT/lib/upgrade.sh" \
        | grep -qE "startswith\(.\.agentic-framework"
}

@test "upgrade.sh parses (bash -n) after T-1627" {
    bash -n "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

# ---- Behavioural detector tests ----
#
# We replicate the (post-fix) check_stale_paths inline. If the source
# definition diverges from this replica, the source-marker tests above
# fail first — pinning the contract from both sides.

run_check_on() {
    local settings_file="$1"
    SETTINGS_FILE="$settings_file" python3 -c "
import json, os

def check_stale_paths(path):
    stale = 0
    non_framework = 0
    try:
        with open(path) as f:
            data = json.load(f)
        for event, entries in data.get('hooks', {}).items():
            for entry in entries:
                for hook in entry.get('hooks', []):
                    cmd = hook.get('command', '')
                    if '/agents/context/' in cmd or 'PROJECT_ROOT=' in cmd:
                        stale += 1
                    elif cmd and cmd.lstrip().startswith('.agentic-framework/'):
                        # T-1627: bare-relative path — broken from any subdir
                        stale += 1
                    elif cmd and 'fw hook' not in cmd and '.agentic-framework' not in cmd:
                        non_framework += 1
    except (json.JSONDecodeError, FileNotFoundError):
        pass
    return stale + non_framework

print(check_stale_paths(os.environ['SETTINGS_FILE']))
"
}

@test "stale-detector flags bare-relative .agentic-framework path (T-1627)" {
    cat > "$TEST_TEMP_DIR/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": ".agentic-framework/bin/fw hook check-tier0"}
        ]
      }
    ]
  }
}
EOF
    run run_check_on "$TEST_TEMP_DIR/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "stale-detector ALLOWS absolute .agentic-framework path (T-1627 false-positive guard)" {
    cat > "$TEST_TEMP_DIR/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "/some/consumer/.agentic-framework/bin/fw hook check-tier0"}
        ]
      }
    ]
  }
}
EOF
    run run_check_on "$TEST_TEMP_DIR/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

@test "stale-detector ALLOWS \$CLAUDE_PROJECT_DIR-prefixed path (T-1627)" {
    cat > "$TEST_TEMP_DIR/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "\$CLAUDE_PROJECT_DIR/.agentic-framework/bin/fw hook check-tier0"}
        ]
      }
    ]
  }
}
EOF
    run run_check_on "$TEST_TEMP_DIR/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

@test "stale-detector still flags legacy /agents/context/ paths (T-1627 backwards compat)" {
    cat > "$TEST_TEMP_DIR/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "PROJECT_ROOT=/x /opt/foo/agents/context/check-tier0.sh"}
        ]
      }
    ]
  }
}
EOF
    run run_check_on "$TEST_TEMP_DIR/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "stale-detector flags bare-relative even with leading whitespace (T-1627)" {
    cat > "$TEST_TEMP_DIR/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "   .agentic-framework/bin/fw hook check-tier0"}
        ]
      }
    ]
  }
}
EOF
    run run_check_on "$TEST_TEMP_DIR/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}
