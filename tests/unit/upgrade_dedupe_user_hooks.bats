#!/usr/bin/env bats
# T-1481 — `fw upgrade --dedupe-user-hooks` opt-in remediation. Removes
# framework hooks from $HOME/.claude/settings.json that duplicate the
# project-level config; always backs up first. T-1479/T-1480 surface the
# overlap; this gives the user a one-command fix.

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

@test "lib/upgrade.sh has --dedupe-user-hooks flag in arg parsing (T-1481)" {
    grep -q -- "--dedupe-user-hooks) dedupe_user_hooks=true" "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "lib/upgrade.sh defines _do_dedupe_user_hooks helper (T-1481)" {
    grep -q "_do_dedupe_user_hooks()" "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "fw upgrade --help mentions --dedupe-user-hooks (T-1481)" {
    grep -q -- "--dedupe-user-hooks.*Remove framework hooks" "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "_do_dedupe_user_hooks creates a timestamped backup (T-1481)" {
    grep -qE '\$\{user_settings\}\.bak-\$\(date \+%s\)' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "lib/upgrade.sh parses (bash -n) (T-1481)" {
    bash -n "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

# ---- Behavioural: run the helper end-to-end via a stripped-down test harness ----

# Source ONLY _do_dedupe_user_hooks. Other functions need framework state we don't
# want to set up. Extract the helper and source it.
_load_helper() {
    # Source by extracting just _do_dedupe_user_hooks via awk.
    # Define color constants the helper uses.
    GREEN='' YELLOW='' RED='' CYAN='' NC=''
    eval "$(awk '/^_do_dedupe_user_hooks\(\) \{/,/^}$/' "$FRAMEWORK_ROOT/lib/upgrade.sh")"
}

@test "behavioural: identifies and removes duplicate, preserves non-framework hooks" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{
  "hooks": {
    "PreCompact": [
      {"matcher":"","hooks":[{"type":"command","command":".agentic-framework/bin/fw hook pre-compact"}]}
    ],
    "PostToolUse": [
      {"matcher":"","hooks":[{"type":"command","command":"echo my-custom-hook"}]}
    ]
  }
}
EOF
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    _load_helper
    run _do_dedupe_user_hooks "$TEST_TEMP_DIR/user.json" "$TEST_TEMP_DIR/proj.json" false
    [ "$status" -eq 0 ]
    # Backup created
    ls "$TEST_TEMP_DIR"/user.json.bak-* >/dev/null
    # User-level pre-compact gone, custom hook preserved
    ! grep -q "fw hook pre-compact" "$TEST_TEMP_DIR/user.json"
    grep -q "my-custom-hook" "$TEST_TEMP_DIR/user.json"
}

@test "behavioural: dry-run does NOT modify user file" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":".agentic-framework/bin/fw hook pre-compact"}]}]}}
EOF
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    local before_md5
    before_md5=$(md5sum "$TEST_TEMP_DIR/user.json" | cut -d' ' -f1)
    _load_helper
    run _do_dedupe_user_hooks "$TEST_TEMP_DIR/user.json" "$TEST_TEMP_DIR/proj.json" true
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD REMOVE"* ]]
    local after_md5
    after_md5=$(md5sum "$TEST_TEMP_DIR/user.json" | cut -d' ' -f1)
    [ "$before_md5" = "$after_md5" ]
    # No backup in dry-run
    ! ls "$TEST_TEMP_DIR"/user.json.bak-* >/dev/null 2>&1
}

@test "behavioural: no overlap → no backup, OK message" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/different/fw hook other-hook"}]}]}}
EOF
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    _load_helper
    run _do_dedupe_user_hooks "$TEST_TEMP_DIR/user.json" "$TEST_TEMP_DIR/proj.json" false
    [ "$status" -eq 0 ]
    [[ "$output" == *"no duplicates"* ]]
    ! ls "$TEST_TEMP_DIR"/user.json.bak-* >/dev/null 2>&1
}

@test "behavioural: malformed user JSON does not crash" {
    cd "$TEST_TEMP_DIR"
    echo "{not json" > user.json
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    _load_helper
    run _do_dedupe_user_hooks "$TEST_TEMP_DIR/user.json" "$TEST_TEMP_DIR/proj.json" false
    # Either WARN+rc=1 or OK+rc=0 — either way, no python traceback and no crash
    ! echo "$output" | grep -qE 'Traceback \(most recent call last\):'
}

@test "behavioural: result is valid JSON after removal" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{
  "hooks": {
    "PreCompact": [
      {"matcher":"","hooks":[{"type":"command","command":".agentic-framework/bin/fw hook pre-compact"}]}
    ],
    "PostToolUse": [
      {"matcher":"","hooks":[{"type":"command","command":"echo keep-me"}]}
    ]
  },
  "permissions": {"allow": ["Read(*)"]}
}
EOF
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    _load_helper
    run _do_dedupe_user_hooks "$TEST_TEMP_DIR/user.json" "$TEST_TEMP_DIR/proj.json" false
    [ "$status" -eq 0 ]
    # Resulting file must be valid JSON
    python3 -c "import json; json.load(open('$TEST_TEMP_DIR/user.json'))"
    # And the unrelated 'permissions' top-level key must survive
    python3 -c "import json,sys; d=json.load(open('$TEST_TEMP_DIR/user.json')); sys.exit(0 if d.get('permissions',{}).get('allow') else 1)"
}
