#!/usr/bin/env bats
# T-1500: Tier 0 hash drift on retry-after-approval.
#
# Root cause: check-tier0.sh hashed $COMMAND raw. When an agent regenerated
# a blocked command for retry (extra whitespace, trailing newline, reflowed
# args), the SHA-256 digest drifted from the stored approval and the hook
# re-blocked. Approval was effectively single-use only for byte-identical
# retries.
#
# Fix: normalize whitespace before hashing — collapse runs of [:space:] to a
# single space, trim leading/trailing. Same human-readable command yields
# same hash regardless of incidental whitespace.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/approvals" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
    APPROVAL_FILE="$TEST_TEMP_DIR/.context/working/.tier0-approval"
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

# Pre-approve using NORMALIZED hash (matches what the hook now computes).
_pre_approve_normalized() {
    local cmd="$1"
    local normalized hash
    normalized=$(printf '%s' "$cmd" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')
    hash=$(printf '%s' "$normalized" | sha256sum | awk '{print $1}')
    echo "$hash $(date +%s)" > "$APPROVAL_FILE"
}

@test "tier0_hash_normalization: approval written for canonical form matches retry with extra internal whitespace" {
    local approved="git push --force-with-lease onedev master"
    local retry="git push  --force-with-lease   onedev    master"
    _pre_approve_normalized "$approved"

    run _run_hook "$retry"
    [ "$status" -eq 0 ]
    # Approval consumed exactly once
    [ ! -f "$APPROVAL_FILE" ]
}

@test "tier0_hash_normalization: approval matches retry with trailing whitespace" {
    local approved="git push --force-with-lease onedev master"
    local retry="git push --force-with-lease onedev master   "
    _pre_approve_normalized "$approved"

    run _run_hook "$retry"
    [ "$status" -eq 0 ]
    [ ! -f "$APPROVAL_FILE" ]
}

@test "tier0_hash_normalization: approval matches retry with embedded newline" {
    local approved="git push --force-with-lease onedev master"
    # Same command but with a tab/newline reflow between args
    local retry=$'git push --force-with-lease\nonedev master'
    _pre_approve_normalized "$approved"

    run _run_hook "$retry"
    [ "$status" -eq 0 ]
    [ ! -f "$APPROVAL_FILE" ]
}

@test "tier0_hash_normalization: structurally different command does NOT match (security boundary)" {
    local approved="git push --force-with-lease onedev master"
    # Whitespace-equivalent? No — appended destructive command differs structurally.
    local malicious="git push --force-with-lease onedev master ; rm -rf /tmp/xx"
    _pre_approve_normalized "$approved"

    run _run_hook "$malicious"
    # Must still BLOCK (different command, different hash even after normalization).
    # CRITICAL: the malicious command did NOT receive exit 0 — security boundary held.
    [ "$status" -eq 2 ]
    # Pre-existing defensive policy (line 266): any mismatched approval is
    # also cleaned up, forcing re-approval of the original command. This is
    # NOT introduced by T-1500; preserved to confirm no regression.
    [ ! -f "$APPROVAL_FILE" ]
}

@test "tier0_hash_normalization: idempotency sentinel uses normalized hash too (T-1508 still intact)" {
    local approved="git push --force-with-lease onedev master"
    local retry_a="git push --force-with-lease onedev master"
    local retry_b="git push  --force-with-lease  onedev master"
    _pre_approve_normalized "$approved"

    # First fire (canonical form) — consume approval, write sentinel
    run _run_hook "$retry_a"
    [ "$status" -eq 0 ]
    [ -f "${APPROVAL_FILE}.consumed" ]

    # Second fire from duplicate hook reg, but with whitespace variant —
    # sentinel must short-circuit (normalized hashes match)
    run _run_hook "$retry_b"
    [ "$status" -eq 0 ]
    # No new pending block created
    [ ! -f "${APPROVAL_FILE}.pending" ]
}
