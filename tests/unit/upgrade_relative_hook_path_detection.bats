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
# T-4380: these run the SHIPPED check_stale_paths, cut out of lib/upgrade.sh (it
# is the Python function inside the `fw upgrade` hook analysis), not a replica.
# The old replica stayed green when the bare-relative branch in upgrade.sh was
# disabled (the T-1627 bug itself).

run_check_on() {
    local settings_file="$1"
    local fn="$TEST_TEMP_DIR/check_stale_paths.py"
    awk '/^def check_stale_paths\(path\):/{f=1} f{print} f && /^    return stale, non_framework/{exit}' \
        "$FRAMEWORK_ROOT/lib/upgrade.sh" > "$fn"
    [ -s "$fn" ] || { echo "extraction empty - did check_stale_paths move?" >&2; return 1; }
    grep -q "startswith" "$fn" || { echo "extraction lost the bare-relative branch" >&2; return 1; }
    SETTINGS_FILE="$settings_file" FN_FILE="$fn" python3 -c "
import json, os
exec(open(os.environ['FN_FILE']).read())
stale, non_framework = check_stale_paths(os.environ['SETTINGS_FILE'])
print(stale + non_framework)
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
