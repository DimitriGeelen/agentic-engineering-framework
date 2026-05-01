#!/usr/bin/env bats
# T-1630 (B-4 of T-1626) — SessionStart resume hook warns on broken hooks.
#
# When `agents/context/post-compact-resume.sh` fires (SessionStart:compact /
# SessionStart:resume), it probes every PreToolUse/PostToolUse hook from /tmp
# (via `lib/doctor-hook-exercise.py`, shared with B-3a / T-1629) and appends
# a warning section to the additionalContext JSON if any hooks fail to
# resolve. This makes the T-1626 witness scenario surface in the agent's
# session-start context — not just on a manual `fw doctor`.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    # Build a minimal "consumer" project the resume hook can chdir into.
    mkdir -p "$TEST_TEMP_DIR/.claude"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
    mkdir -p "$TEST_TEMP_DIR/.context/handovers"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/.tasks/templates"
    cat > "$TEST_TEMP_DIR/.framework.yaml" <<EOF
framework_root: $FRAMEWORK_ROOT
EOF
    # Minimal LATEST.md so the resume hook has something to read.
    cat > "$TEST_TEMP_DIR/.context/handovers/LATEST.md" <<'EOF'
---
session_id: test
---
# Session Handover: test
## Where We Are
Test fixture
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

run_resume() {
    cd "$TEST_TEMP_DIR"
    PROJECT_ROOT="$TEST_TEMP_DIR" \
        bash "$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh" 2>/dev/null
}

# ---- Source-level invariant ----

@test "post-compact-resume.sh references the hook-exercise helper (T-1630)" {
    grep -qE "doctor-hook-exercise|hook-self-test|T-1630" \
        "$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh"
}

# ---- Behavioural ----

@test "resume hook appends warning when settings.json has a broken bare-relative path" {
    cat > "$TEST_TEMP_DIR/.claude/settings.json" <<EOF
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
    run run_resume
    [ "$status" -eq 0 ]
    # The output is JSON with additionalContext containing the warning.
    echo "$output" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
ctx = data['hookSpecificOutput']['additionalContext']
assert 'Hook' in ctx and ('broken' in ctx.lower() or 'fail' in ctx.lower() or 'resolve' in ctx.lower()), \
    f'expected hook warning in additionalContext, got: {ctx[-500:]}'
"
}

@test "resume hook stays silent on healthy hooks" {
    cat > "$TEST_TEMP_DIR/.claude/settings.json" <<EOF
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
    run run_resume
    [ "$status" -eq 0 ]
    # additionalContext should NOT contain a "broken hook" / "failed to resolve" warning section.
    echo "$output" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
ctx = data['hookSpecificOutput']['additionalContext']
assert 'Broken Hook' not in ctx and 'failed to resolve' not in ctx.lower(), \
    f'unexpected hook warning in healthy-case context: {ctx[-500:]}'
"
}

@test "resume hook degrades silently when helper script is missing" {
    # Simulate degraded install: rename helper to make probe path fail.
    cat > "$TEST_TEMP_DIR/.claude/settings.json" <<EOF
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
    # Use FW_DOCTOR_HOOK_EXERCISE override to point at non-existent path
    cd "$TEST_TEMP_DIR"
    run env FW_DOCTOR_HOOK_EXERCISE="/nonexistent/helper.py" PROJECT_ROOT="$TEST_TEMP_DIR" \
        bash "$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh"
    [ "$status" -eq 0 ]
    # Output is still valid JSON with additionalContext (script didn't crash).
    echo "$output" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert 'additionalContext' in data['hookSpecificOutput']
"
}
