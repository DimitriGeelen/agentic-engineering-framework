#!/usr/bin/env bats
# T-1504: fw hook-enable must emit absolute hook commands.
#
# Background: bin/hook-enable.sh:73 used to emit ".agentic-framework/bin/fw"
# (relative). Claude Code's hook runner is POSIX `sh -c`, which does not
# chdir to the project root before invoking, so the relative path resolved
# only when the parent shell happened to be at project root. Downstream
# 003-NTB-ATC-Plugin observed 680 silent "non-blocking status code" failures
# in one session JSONL.
#
# Fix mirrors lib/init.sh:584 (T-1364, G-053-A): canonicalize the project
# root from --file path, detect framework-mode (FRAMEWORK.md + bin/fw) vs
# consumer-mode (.agentic-framework/bin/fw), emit absolute path either way.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK_ENABLE="$FRAMEWORK_ROOT/bin/hook-enable.sh"
    [ -x "$HOOK_ENABLE" ] || skip "hook-enable.sh not executable"

    # Build a minimal consumer-mode project: PROJECT/.agentic-framework/bin/fw + .claude/settings.json
    PROJECT_DIR="$(cd "$TEST_TEMP_DIR" && pwd)/proj"
    mkdir -p "$PROJECT_DIR/.agentic-framework/bin" "$PROJECT_DIR/.claude"
    # Stub fw — needs to be executable for the absolute-path-x check
    cat > "$PROJECT_DIR/.agentic-framework/bin/fw" <<'STUB'
#!/usr/bin/env bash
echo "stub-fw $*"
STUB
    chmod +x "$PROJECT_DIR/.agentic-framework/bin/fw"
    # Empty hooks scaffold
    echo '{"hooks": {}}' > "$PROJECT_DIR/.claude/settings.json"
    SETTINGS="$PROJECT_DIR/.claude/settings.json"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "hook-enable: emits absolute path for consumer-mode project" {
    run "$HOOK_ENABLE" --name check-active-task --event PreToolUse --matcher "Write|Edit" --file "$SETTINGS"
    [ "$status" -eq 0 ]

    # Extract the registered command and assert it's absolute and points into the project
    local cmd
    cmd=$(python3 -c "
import json
with open('$SETTINGS') as f: d = json.load(f)
print(d['hooks']['PreToolUse'][0]['hooks'][0]['command'])
")
    [[ "$cmd" == /* ]]
    [[ "$cmd" == *"$PROJECT_DIR/.agentic-framework/bin/fw hook check-active-task"* ]]
}

@test "hook-enable: registered command resolves correctly under sh -c with arbitrary cwd (the original bug)" {
    run "$HOOK_ENABLE" --name check-active-task --event PreToolUse --matcher "Write|Edit" --file "$SETTINGS"
    [ "$status" -eq 0 ]

    local cmd
    cmd=$(python3 -c "
import json
with open('$SETTINGS') as f: d = json.load(f)
print(d['hooks']['PreToolUse'][0]['hooks'][0]['command'])
")
    # Reproduce the failure mode: sh -c from an unrelated cwd (mimics Claude Code hook runner)
    cd /tmp
    run sh -c "$cmd"
    [ "$status" -eq 0 ]
    [[ "$output" == *"stub-fw hook check-active-task"* ]]
}

@test "hook-enable: idempotent — same hook re-registered yields no-op (not a duplicate entry)" {
    run "$HOOK_ENABLE" --name check-active-task --event PreToolUse --matcher "Write|Edit" --file "$SETTINGS"
    [ "$status" -eq 0 ]
    run "$HOOK_ENABLE" --name check-active-task --event PreToolUse --matcher "Write|Edit" --file "$SETTINGS"
    [ "$status" -eq 0 ]

    # Should be exactly ONE entry, not two
    local count
    count=$(python3 -c "
import json
with open('$SETTINGS') as f: d = json.load(f)
print(len(d['hooks']['PreToolUse'][0]['hooks']))
")
    [ "$count" -eq 1 ]
}

@test "hook-enable: framework-mode (FRAMEWORK.md + bin/fw) emits bin/fw not .agentic-framework/bin/fw" {
    # Convert PROJECT_DIR to a framework-mode layout
    rm -rf "$PROJECT_DIR/.agentic-framework"
    mkdir -p "$PROJECT_DIR/bin"
    cat > "$PROJECT_DIR/bin/fw" <<'STUB'
#!/usr/bin/env bash
echo "fw-from-bin $*"
STUB
    chmod +x "$PROJECT_DIR/bin/fw"
    touch "$PROJECT_DIR/FRAMEWORK.md"

    run "$HOOK_ENABLE" --name check-active-task --event PreToolUse --matcher "Write|Edit" --file "$SETTINGS"
    [ "$status" -eq 0 ]

    local cmd
    cmd=$(python3 -c "
import json
with open('$SETTINGS') as f: d = json.load(f)
print(d['hooks']['PreToolUse'][0]['hooks'][0]['command'])
")
    [[ "$cmd" == "$PROJECT_DIR/bin/fw hook check-active-task" ]]
}
