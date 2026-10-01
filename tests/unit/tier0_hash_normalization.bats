#!/usr/bin/env bats
# Exact-text Tier 0 approvals hash the ORIGINAL command bytes (T-3593 round 7).
#
# History: T-1500 collapsed whitespace before hashing so a reflowed retry still
# matched its approval. That also merged different commands: quoted whitespace
# is part of an argument, so `rm -rf ./ "a  b"` and `rm -rf ./ "a b"` (two
# different paths) shared one approval (codex round 6 HIGH). Round 7 removes all
# normalisation. Retries no longer need it: duplicate fires of ONE tool call are
# recognised by tool_use_id (round 4), and mapped commands match by action.
# (File name kept for history; the suite now pins the opposite rule.)

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

# $2 = tool_use_id (absent = the field is not in the payload).
_run_hook() {
    local cmd="$1" id="${2:-}"
    local json
    json=$(python3 -c "
import json, sys
d = {'tool_input': {'command': sys.argv[1]}, 'cwd': sys.argv[3]}
if sys.argv[2]:
    d['tool_use_id'] = sys.argv[2]
print(json.dumps(d))" "$cmd" "$id" "$TEST_TEMP_DIR")
    echo "$json" | bash "$HOOK"
}

# Approve the exact bytes of $1 (what the hook now computes).
_pre_approve_raw() {
    local hash
    hash=$(printf '%s' "$1" | sha256sum | awk '{print $1}')
    echo "$hash $(date +%s)" > "$APPROVAL_FILE"
}

@test "tier0_hash: the byte-identical command matches its approval" {
    local cmd="git push --force-with-lease onedev master"
    _pre_approve_raw "$cmd"
    run _run_hook "$cmd"
    [ "$status" -eq 0 ]
    [ ! -f "$APPROVAL_FILE" ]
}

@test "tier0_hash: the pending hash the hook writes is the raw-byte sha256" {
    local cmd='rm -rf ./ "a  b"'
    run _run_hook "$cmd"
    [ "$status" -eq 2 ]
    local want
    want=$(printf '%s' "$cmd" | sha256sum | awk '{print $1}')
    [ "$(awk '{print $1}' "${APPROVAL_FILE}.pending")" = "$want" ]
}

@test "tier0_hash: quoted whitespace is part of the argument — 'a  b' approval does not admit 'a b' (codex R6 HIGH)" {
    _pre_approve_raw 'rm -rf ./ "a  b"'
    run _run_hook 'rm -rf ./ "a b"'
    [ "$status" -eq 2 ]
    _pre_approve_raw 'rm -rf ./ "a b"'
    run _run_hook 'rm -rf ./ "a  b"'
    [ "$status" -eq 2 ]
    _pre_approve_raw "rm -rf ./ 'a	b'"
    run _run_hook "rm -rf ./ 'a b'"
    [ "$status" -eq 2 ]
}

@test "tier0_hash: unquoted whitespace variants are distinct texts too (no normalisation anywhere)" {
    local approved="git push --force-with-lease onedev master | tail -3"
    for retry in "git push  --force-with-lease onedev master | tail -3" \
                 "git push --force-with-lease onedev master | tail -3 " \
                 $'git push --force-with-lease onedev master | tail -3\n' \
                 " git push --force-with-lease onedev master | tail -3"; do
        _pre_approve_raw "$approved"
        run _run_hook "$retry"
        [ "$status" -eq 2 ] || { echo "admitted: [$retry]"; return 1; }
    done
}

@test "tier0_hash: structurally different command does NOT match (security boundary)" {
    _pre_approve_raw "git push --force-with-lease onedev master"
    run _run_hook "git push --force-with-lease onedev master ; rm -rf /tmp/xx"
    [ "$status" -eq 2 ]
    [ ! -f "$APPROVAL_FILE" ]
}

@test "tier0_hash: duplicate fire of the SAME tool call passes via tool_use_id (T-1508 intact)" {
    local cmd="git push --force-with-lease onedev master | tail -3"
    _pre_approve_raw "$cmd"
    run _run_hook "$cmd" toolu_dup
    [ "$status" -eq 0 ]
    [ -f "${APPROVAL_FILE}.consumed" ]
    run _run_hook "$cmd" toolu_dup
    [ "$status" -eq 0 ]
    [ ! -f "${APPROVAL_FILE}.pending" ]
    # A different call with the same text gets no grace.
    run _run_hook "$cmd" toolu_other
    [ "$status" -eq 2 ]
}
