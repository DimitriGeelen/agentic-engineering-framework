#!/usr/bin/env bats
# T-2499: loud unsupervised-session notice.
#
# The arc-012 continuous-run auto-restart loop (budget-critical → auto-handover →
# .restart-requested → claude-fw restart → directive re-injection) only fires when
# the session runs under the `claude-fw` wrapper, which exports
# FW_CLAUDE_FW_SUPERVISED=1. A plain `claude` launch leaves it unset → budget-gate
# writes the restart signal into the void and the session silently overruns
# (the 300K→350K bug). This pins that the unsupervised state is made LOUD at two
# surfaces: the budget hook (warn/urgent/critical) and `fw doctor`.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
NOTICE="Unsupervised session (not under claude-fw)"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

write_status() {
    local level="$1"
    local tokens="${2:-100000}"
    local timestamp=$(date +%s)
    cat > "$PROJECT_ROOT/.context/working/.budget-status" <<EOF
{"level": "$level", "tokens": $tokens, "timestamp": $timestamp, "source": "test"}
EOF
}

# Run the budget-gate hook with an explicit supervision state.
# extra_input lets a test target a blocked source-file Write (critical block path).
run_gate_sup() {
    local supervised="$1"   # 0 | 1
    local tool_name="${2:-Read}"
    local extra_input="${3:-}"
    local json
    if [ -n "$extra_input" ]; then
        json="{\"tool_name\": \"$tool_name\", \"tool_input\": {$extra_input}}"
    else
        json="{\"tool_name\": \"$tool_name\", \"tool_input\": {}}"
    fi
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' CONTEXT_DIR='$PROJECT_ROOT/.context' HOME='$HOME' FW_CLAUDE_FW_SUPERVISED='$supervised' '$HOOK'"
}

# --- budget-gate notice: unsupervised → present ---

@test "T-2499: warn + unsupervised → notice present" {
    write_status "warn" 230000
    run_gate_sup 0 "Read"
    [[ "$output" == *"$NOTICE"* ]]
}

@test "T-2499: urgent + unsupervised → notice present" {
    write_status "urgent" 260000
    run_gate_sup 0 "Read"
    [[ "$output" == *"$NOTICE"* ]]
}

# At critical, allowed tools (Read) exit before the block-path notice — by then
# the notice already fired on every warn+urgent call. The moment it matters most
# (a blocked source Write) does carry it:
@test "T-2499: critical block + unsupervised → notice present" {
    write_status "critical" 290000
    run_gate_sup 0 "Write" "\"file_path\": \"/some/project/src/main.py\""
    [ "$status" -eq 2 ]
    [[ "$output" == *"$NOTICE"* ]]
}

# --- budget-gate notice: supervised → absent ---

@test "T-2499: warn + supervised → notice absent" {
    write_status "warn" 230000
    run_gate_sup 1 "Read"
    [[ "$output" != *"$NOTICE"* ]]
}

@test "T-2499: critical block + supervised → notice absent" {
    write_status "critical" 290000
    run_gate_sup 1 "Write" "\"file_path\": \"/some/project/src/main.py\""
    [ "$status" -eq 2 ]
    [[ "$output" != *"$NOTICE"* ]]
}

# --- budget-gate notice: ok level never warns either way ---

@test "T-2499: ok + unsupervised → no notice (nothing to recover from)" {
    write_status "ok" 50000
    run_gate_sup 0 "Read"
    [[ "$output" != *"$NOTICE"* ]]
}

# --- fw doctor supervision line (AC4) ---

@test "T-2499: doctor inside claude session + unsupervised → WARN line" {
    write_status "warn" 230000
    run bash -c "cd '$FRAMEWORK_ROOT' && CLAUDECODE=1 FW_CLAUDE_FW_SUPERVISED='' PROJECT_ROOT='$PROJECT_ROOT' bin/fw doctor --quick 2>&1"
    [[ "$output" == *"Unsupervised session (not under claude-fw)"* ]]
    [[ "$output" == *"auto-restart will NOT fire"* ]]
}

@test "T-2499: doctor inside claude session + supervised → OK line" {
    run bash -c "cd '$FRAMEWORK_ROOT' && CLAUDECODE=1 FW_CLAUDE_FW_SUPERVISED=1 PROJECT_ROOT='$PROJECT_ROOT' bin/fw doctor --quick 2>&1"
    [[ "$output" == *"Session supervised by claude-fw"* ]]
}

@test "T-2499: doctor outside claude session → SKIP (no false alarm for human terminal)" {
    run bash -c "cd '$FRAMEWORK_ROOT' && unset CLAUDECODE FW_CLAUDE_FW_SUPERVISED; PROJECT_ROOT='$PROJECT_ROOT' bin/fw doctor --quick 2>&1"
    [[ "$output" == *"Session supervision (not inside a Claude Code session)"* ]]
}
