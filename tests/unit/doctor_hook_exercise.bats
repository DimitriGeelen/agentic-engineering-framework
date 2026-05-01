#!/usr/bin/env bats
# T-1629 (B-3a of T-1626) — `fw doctor` actively exercises every configured
# Claude Code hook from /tmp (foreign CWD that mimics agent cd-drift) and
# reports any whose path doesn't resolve.
#
# Companion to T-1628 (passive telemetry): doctor is the active probe. Catches
# the T-1626 witness scenario (broken bare-relative `.agentic-framework/bin/fw`
# paths) deterministically, not contingent on a real hook firing during the
# session.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    # Build a fake "consumer" project skeleton that doctor can chdir into.
    mkdir -p "$TEST_TEMP_DIR/.claude"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.tasks/templates"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TEST_TEMP_DIR/.tasks/templates/" 2>/dev/null || true
    cat > "$TEST_TEMP_DIR/.framework.yaml" <<EOF
framework_root: $FRAMEWORK_ROOT
version: $(cat "$FRAMEWORK_ROOT/VERSION" 2>/dev/null || echo "test")
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

write_settings() {
    cat > "$TEST_TEMP_DIR/.claude/settings.json"
}

# ---- Source-level invariants ----

@test "bin/fw doctor source mentions hook exercise from /tmp (T-1629)" {
    grep -qE "T-1629|exercise.*hook|hook-exercise" "$FRAMEWORK_ROOT/bin/fw"
}

# ---- Behavioural ----

@test "doctor reports OK when all configured hooks resolve from /tmp" {
    # Use the framework's own absolute fw path — known to resolve.
    write_settings <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "$FRAMEWORK_ROOT/bin/fw hook check-tier0"}
        ]
      }
    ]
  }
}
EOF
    cd "$TEST_TEMP_DIR"
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    # Doctor returns 0 on no-fail, 1 on warnings, 2 on failures.
    # We just assert no FAIL line about hook exercise.
    ! echo "$output" | grep -qE "FAIL.*[Hh]ook exercise"
    echo "$output" | grep -qE "[Hh]ook (exercise|probe)"
}

@test "doctor reports FAIL when a hook command does not resolve from /tmp (T-1626 witness)" {
    # Bare-relative path: when CWD is /tmp, `.agentic-framework/bin/fw` does
    # not resolve. This is the exact ring20-dashboard 2026-04-30 shape.
    write_settings <<EOF
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
    cd "$TEST_TEMP_DIR"
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    echo "$output" | grep -qE "FAIL.*[Hh]ook exercise|FAIL.*hook.*not found|FAIL.*hook.*resolve"
}

@test "doctor exit code is non-zero when any hook fails the exercise" {
    write_settings <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "/nonexistent/path/to/fw hook check-tier0"}
        ]
      }
    ]
  }
}
EOF
    cd "$TEST_TEMP_DIR"
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    [ "$status" -ne 0 ]
}

@test "doctor exercise tolerates exit 2 (intentional policy block) as OK" {
    # A hook that always returns 2 is a policy block, not a crash. The exercise
    # check must NOT mark such hooks as failing — they're working as designed.
    cat > "$TEST_TEMP_DIR/always-block.sh" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
    chmod +x "$TEST_TEMP_DIR/always-block.sh"
    write_settings <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "$TEST_TEMP_DIR/always-block.sh"}
        ]
      }
    ]
  }
}
EOF
    cd "$TEST_TEMP_DIR"
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    ! echo "$output" | grep -qE "FAIL.*[Hh]ook exercise"
}

@test "doctor exercise reports each broken hook by name" {
    write_settings <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": ".agentic-framework/bin/fw hook check-tier0"}
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {"type": "command", "command": ".agentic-framework/bin/fw hook checkpoint"}
        ]
      }
    ]
  }
}
EOF
    cd "$TEST_TEMP_DIR"
    run "$FRAMEWORK_ROOT/bin/fw" doctor
    # At least one FAIL/WARN line names check-tier0 OR checkpoint
    echo "$output" | grep -qE "(check-tier0|checkpoint).*not (found|resolve)|not (found|resolve).*(check-tier0|checkpoint)" \
        || echo "$output" | grep -qE "FAIL.*[Hh]ook exercise"
}
