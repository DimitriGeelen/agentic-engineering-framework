#!/usr/bin/env bats
# T-4005 — budget-gate.sh failed OPEN when its first python3 call died. RESULT came
# back empty, STATUS_LEVEL defaulted to 'unknown', the fast path was skipped, the
# slow path's python3 calls failed too, and the gate exited 0 even with a cached
# level of critical. A crashed parser at a cached critical level must block new
# work; wrap-up (git commit/add/push, fw handover, fw context focus, reads, writes
# under .context/ .tasks/ .claude/) must stay allowed.
#
# Fixtures only: a stub python3 that exits 1 is first on PATH, and the cache is
# written by hand. FW_CHECKPOINT_SH=/bin/true keeps the critical path from starting
# a real handover.

load ../test_helper

BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$TEST_TEMP_DIR/home" "$TEST_TEMP_DIR/stub"
    echo "session_id: S-TEST-0001" > "$PROJ/.context/working/session.yaml"
    echo "2" > "$PROJ/.context/working/.budget-gate-counter"
    # The stub python3 shadows the real one for every call in the gate.
    printf '#!/bin/bash\nexit 1\n' > "$TEST_TEMP_DIR/stub/python3"
    chmod +x "$TEST_TEMP_DIR/stub/python3"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# _cache LEVEL — fresh cache for the gate to read (age well under STATUS_MAX_AGE).
_cache() {
    printf '{"level": "%s", "tokens": 290000, "timestamp": %d, "session_id": "S-TEST-0001", "source": "budget-gate"}' \
        "$1" "$(date +%s)" > "$PROJ/.context/working/.budget-status"
}

# _gate JSON — feed one PreToolUse payload to the gate with python3 dead.
_gate() {
    printf '%s' "$1" > "$TEST_TEMP_DIR/input.json"
    run bash -c "PATH='$TEST_TEMP_DIR/stub:$PATH' PROJECT_ROOT='$PROJ' CONTEXT_DIR='$PROJ/.context' HOME='$TEST_TEMP_DIR/home' FW_CONTEXT_WINDOW=300000 FW_CHECKPOINT_SH=/bin/true bash '$BUDGET_GATE' < '$TEST_TEMP_DIR/input.json'"
}

# _bash CMD — a Bash PreToolUse payload for the given command string.
_bash() {
    _gate "{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"
}

# _write FILE — a Write PreToolUse payload for the given path.
_write() {
    _gate "{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$1\",\"content\":\"x\"}}"
}

# _edit FILE — an Edit PreToolUse payload for the given path.
_edit() {
    _gate "{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$1\",\"old_string\":\"a\",\"new_string\":\"b\"}}"
}

# --- Blocking: cached critical + dead python3 ---

@test "dead python3 + cached critical: non-wrap-up Bash 'npm run build' is blocked (exit 2) and names the parser failure" {
    _cache critical
    _bash "npm run build"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "BUDGET PARSER FAILED"
    echo "$output" | grep -q "python3"
}

@test "dead python3 + cached critical: Write to lib/x.py is blocked (exit 2)" {
    _cache critical
    _write "/opt/proj/lib/x.py"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "BUDGET PARSER FAILED"
}

@test "dead python3 + cached critical: chained wrap-up 'git add x && npm test' is blocked (exit 2)" {
    _cache critical
    _bash "git add x && npm test"
    [ "$status" -eq 2 ]
}

@test "dead python3 + cached critical: 'git commit -m x; rm -rf build' is blocked (exit 2)" {
    _cache critical
    _bash "git commit -m x; rm -rf build"
    [ "$status" -eq 2 ]
}

@test "dead python3 + cached critical: Write with '..' escaping .context/ is blocked (exit 2)" {
    _cache critical
    _write "/opt/proj/.context/../lib/x.py"
    [ "$status" -eq 2 ]
}

# --- Allowed: cached critical + dead python3, wrap-up stays open ---

@test "dead python3 + cached critical: 'git commit -m x' is allowed (exit 0)" {
    _cache critical
    _bash "git commit -m x"
    [ "$status" -eq 0 ]
}

@test "dead python3 + cached critical: 'git push' is allowed (exit 0)" {
    _cache critical
    _bash "git push"
    [ "$status" -eq 0 ]
}

@test "dead python3 + cached critical: 'bin/fw handover' is allowed (exit 0)" {
    _cache critical
    _bash "bin/fw handover"
    [ "$status" -eq 0 ]
}

@test "dead python3 + cached critical: Read is allowed (exit 0)" {
    _cache critical
    _gate '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/opt/proj/lib/x.py"}}'
    [ "$status" -eq 0 ]
}

@test "dead python3 + cached critical: Edit under .tasks/ is allowed (exit 0)" {
    _cache critical
    _edit "/opt/proj/.tasks/active/T-1.md"
    [ "$status" -eq 0 ]
}

# --- Not critical: dead python3 must behave exactly as before (no new block) ---

@test "dead python3 + cached ok: 'npm run build' is allowed (exit 0)" {
    _cache ok
    _bash "npm run build"
    [ "$status" -eq 0 ]
}

@test "dead python3 + cached warn: 'npm run build' is allowed (exit 0)" {
    _cache warn
    _bash "npm run build"
    [ "$status" -eq 0 ]
}

@test "dead python3 + cached urgent: 'npm run build' is allowed (exit 0)" {
    _cache urgent
    _bash "npm run build"
    [ "$status" -eq 0 ]
}

@test "dead python3 + no .budget-status file: 'npm run build' is allowed (exit 0)" {
    rm -f "$PROJ/.context/working/.budget-status"
    _bash "npm run build"
    [ "$status" -eq 0 ]
}
