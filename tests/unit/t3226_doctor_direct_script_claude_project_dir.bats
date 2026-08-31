#!/usr/bin/env bats
# T-3226 — doctor's hook-config check expands ${CLAUDE_PROJECT_DIR} only inside
# the `fw hook ...` branch (bin/fw:2631, T-2709). A hook naming its script
# DIRECTLY (no `fw hook` in the command, e.g. the Stop hook
# `${CLAUDE_PROJECT_DIR}/agents/context/stop-driver.sh`) fell through to
# os.path.exists() on the literal, unexpanded string and was always reported
# missing — 1 of 29 hook commands, and it was the Stop hook that drives the
# continuous-run loop.
#
# Pins three cases against the fix at bin/fw (direct-script branch, ~line
# 2686): expansion resolves an existing script (no false FAIL), a genuinely
# missing script still FAILs (mutation control — the fix must not silence
# real breakage), and a non-executable resolved script WARNs rather than
# being reported as "not found" (the executable check is unreachable until
# the existence check uses the resolved path).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    mkdir -p "$TEST_TEMP_DIR/.claude"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.tasks/templates"
    mkdir -p "$TEST_TEMP_DIR/agents/context"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TEST_TEMP_DIR/.tasks/templates/" 2>/dev/null || true
    # A real project root is a git repo; doctor's git-hooks check
    # (`git -C "$PROJECT_ROOT" rev-parse --git-path hooks`) runs under bin/fw's
    # `set -euo pipefail` with no `|| true` guard, so a non-git PROJECT_ROOT
    # aborts doctor before it ever reaches the hook-config check under test.
    git -C "$TEST_TEMP_DIR" init -q
    git -C "$TEST_TEMP_DIR" -c user.email=t@t.com -c user.name=t commit -q --allow-empty -m init
    {
        echo "framework_root: $FRAMEWORK_ROOT"
        echo "version: $(cat "$FRAMEWORK_ROOT/VERSION" 2>/dev/null || echo test)"
    } > "$TEST_TEMP_DIR/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

write_settings() {
    cat > "$TEST_TEMP_DIR/.claude/settings.json"
}

@test "doctor does not report a direct-script CLAUDE_PROJECT_DIR hook as missing when it resolves" {
    cat > "$TEST_TEMP_DIR/agents/context/stop-driver.sh" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
    chmod +x "$TEST_TEMP_DIR/agents/context/stop-driver.sh"
    write_settings <<'SETTINGS'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {"type": "command", "command": "${CLAUDE_PROJECT_DIR}/agents/context/stop-driver.sh"}
        ]
      }
    ]
  }
}
SETTINGS
    cd "$TEST_TEMP_DIR"
    export CLAUDE_PROJECT_DIR="$TEST_TEMP_DIR"
    run env -u PROJECT_ROOT "$FRAMEWORK_ROOT/bin/fw" doctor --quick
    ! echo "$output" | grep -qE "script not found: stop-driver\.sh"
}

@test "doctor still FAILs a direct-script CLAUDE_PROJECT_DIR hook that genuinely does not exist (mutation control)" {
    # Deliberately do NOT create agents/context/missing-driver.sh.
    write_settings <<'SETTINGS'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {"type": "command", "command": "${CLAUDE_PROJECT_DIR}/agents/context/missing-driver.sh"}
        ]
      }
    ]
  }
}
SETTINGS
    cd "$TEST_TEMP_DIR"
    export CLAUDE_PROJECT_DIR="$TEST_TEMP_DIR"
    run env -u PROJECT_ROOT "$FRAMEWORK_ROOT/bin/fw" doctor --quick
    echo "$output" | grep -qE "FAIL.*script not found: missing-driver\.sh"
}

@test "doctor WARNs (not FAILs-as-missing) a resolved direct-script CLAUDE_PROJECT_DIR hook that is not executable" {
    cat > "$TEST_TEMP_DIR/agents/context/stop-driver.sh" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
    chmod -x "$TEST_TEMP_DIR/agents/context/stop-driver.sh"
    write_settings <<'SETTINGS'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {"type": "command", "command": "${CLAUDE_PROJECT_DIR}/agents/context/stop-driver.sh"}
        ]
      }
    ]
  }
}
SETTINGS
    cd "$TEST_TEMP_DIR"
    export CLAUDE_PROJECT_DIR="$TEST_TEMP_DIR"
    run env -u PROJECT_ROOT "$FRAMEWORK_ROOT/bin/fw" doctor --quick
    ! echo "$output" | grep -qE "script not found: stop-driver\.sh"
    echo "$output" | grep -qE "script not executable: stop-driver\.sh"
}
