#!/usr/bin/env bats
# T-1508: Tier 0 idempotency under duplicate hook registration.
#
# Root cause (T-1506 RCA): when check-tier0 is registered in BOTH .claude/settings.json
# and ~/.claude/settings.json, every Bash call fires it twice. The first invocation
# consumes the approval (rm -f $APPROVAL_FILE) and exits 0; without a sentinel, the
# second invocation finds no approval and BLOCKS, so every approve+retry ends in BLOCK.
#
# Fix: on consume, write ${APPROVAL_FILE}.consumed (hash + timestamp). Subsequent
# invocations within 5s for the same command short-circuit to allow. Stale sentinels
# (>=5s) are cleaned up so they cannot silently re-allow later commands.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/approvals" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
    APPROVAL_FILE="$TEST_TEMP_DIR/.context/working/.tier0-approval"
    CONSUMED_FILE="${APPROVAL_FILE}.consumed"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_hook() {
    local cmd="$1"
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command': sys.argv[1]}}))" "$cmd")
    echo "$json" | bash "$HOOK"
}

# Pre-approve a command by writing the approval file the way `fw tier0 approve` would
_pre_approve() {
    local cmd="$1"
    local hash
    hash=$(echo -n "$cmd" | sha256sum | awk '{print $1}')
    echo "$hash $(date +%s)" > "$APPROVAL_FILE"
}

@test "tier0_idempotency: first call consumes approval and writes sentinel" {
    local cmd="git push --force-with-lease onedev master"
    _pre_approve "$cmd"
    [ -f "$APPROVAL_FILE" ]
    [ ! -f "$CONSUMED_FILE" ]

    run _run_hook "$cmd"
    [ "$status" -eq 0 ]
    # Approval consumed
    [ ! -f "$APPROVAL_FILE" ]
    # Sentinel written
    [ -f "$CONSUMED_FILE" ]
    # Sentinel hash matches command
    local expected_hash
    expected_hash=$(echo -n "$cmd" | sha256sum | awk '{print $1}')
    grep -q "^$expected_hash " "$CONSUMED_FILE"
}

@test "tier0_idempotency: second call within 5s short-circuits to allow (no new pending block)" {
    local cmd="git push --force-with-lease onedev master"
    _pre_approve "$cmd"

    run _run_hook "$cmd"
    [ "$status" -eq 0 ]

    # Second invocation — sentinel must short-circuit
    run _run_hook "$cmd"
    [ "$status" -eq 0 ]
    # CRITICAL: no new pending block file written by the duplicate fire
    [ ! -f "${APPROVAL_FILE}.pending" ]
    # No approvals/pending-*.yaml written either
    [ -z "$(ls "$TEST_TEMP_DIR/.context/approvals" 2>/dev/null | grep '^pending-' || true)" ]
}

@test "tier0_idempotency: stale sentinel (age>=5s) does NOT silently re-allow" {
    local cmd="git push --force-with-lease onedev master"
    local hash
    hash=$(echo -n "$cmd" | sha256sum | awk '{print $1}')
    # Write sentinel with timestamp 10 seconds in the past (stale)
    echo "$hash $(($(date +%s) - 10))" > "$CONSUMED_FILE"

    run _run_hook "$cmd"
    # Stale sentinel must be ignored → command must be BLOCKED (exit 2)
    [ "$status" -eq 2 ]
}

@test "tier0_idempotency: sentinel for different command does NOT short-circuit unrelated push" {
    local cmd_a="git push --force-with-lease onedev master"
    local cmd_b="git reset --hard HEAD~5"
    local hash_a
    hash_a=$(echo -n "$cmd_a" | sha256sum | awk '{print $1}')
    # Sentinel exists for cmd_a (recently consumed)
    echo "$hash_a $(date +%s)" > "$CONSUMED_FILE"

    # Run cmd_b — must be blocked, sentinel hash differs
    run _run_hook "$cmd_b"
    [ "$status" -eq 2 ]
}

@test "tier0_idempotency: safe command (not destructive) is unaffected by sentinel logic" {
    local cmd="ls -la"
    run _run_hook "$cmd"
    [ "$status" -eq 0 ]
    [ ! -f "$CONSUMED_FILE" ]
}
