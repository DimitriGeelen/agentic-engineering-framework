#!/usr/bin/env bats
# T-4480 (termlink proposal 350, their T-2687): lib/pickup.sh must refuse the
# constant sha256("||") dedup hash and content-free "Pickup:  (from )" tasks,
# and leave a refused envelope in the inbox instead of burying it.

load ../test_helper

CONST_HASH="565d240f5343e625ae579a4d45a770f1f02c6368b5ed4d06da4fbe6f47c28866"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    export PICKUP_DIR="$TEST_TEMP_DIR/.context/pickup"
    export PICKUP_INBOX="$PICKUP_DIR/inbox"
    export PICKUP_PROCESSED="$PICKUP_DIR/processed"
    export PICKUP_REJECTED="$PICKUP_DIR/rejected"
    export PICKUP_AUTO_DEFERRED="$PICKUP_DIR/auto-deferred"
    export PICKUP_DEDUP_LOG="$PICKUP_DIR/dedup.log"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
    # Stub task creation so nothing leaks into the real project; record calls.
    FW_CALLS="$TEST_TEMP_DIR/fw.calls"
    fw() { echo "$*" >> "$FW_CALLS"; echo "File: $TEST_TEMP_DIR/none.md"; }
    pickup_ensure_dirs
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_envelope() {
    local file="$1" summary="$2" project="$3"
    cat > "$file" <<EOF
pickup_id: P-001
version: 1
type: feature-proposal
source:
  project: $project
  task_id: T-042
payload:
  summary: $summary
EOF
}

@test "dedup_hash: missing envelope returns 1 and emits no hash" {
    run pickup_dedup_hash "$TEST_TEMP_DIR/absent.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" != *"$CONST_HASH"* ]]
}

@test "dedup_hash: all-empty fields return 1 instead of the constant digest" {
    local f="$TEST_TEMP_DIR/empty.yaml"
    printf 'pickup_id: P-002\nversion: 1\n' > "$f"
    run pickup_dedup_hash "$f"
    [ "$status" -eq 1 ]
    [[ "$output" != *"$CONST_HASH"* ]]
}

@test "dedup_hash: a normal envelope still hashes (64 hex chars)" {
    local f="$TEST_TEMP_DIR/ok.yaml"
    _envelope "$f" "Real summary" "proj-a"
    run pickup_dedup_hash "$f"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{64}$ ]]
}

@test "record_dedup: uncomputable hash leaves the ledger unchanged" {
    local f="$TEST_TEMP_DIR/empty.yaml"
    printf 'pickup_id: P-002\nversion: 1\n' > "$f"
    run pickup_record_dedup "$f"
    [ "$status" -eq 1 ]
    [ ! -s "$PICKUP_DEDUP_LOG" ]
}

@test "dedup_check: a poisoned constant-hash ledger row does not swallow a failing envelope" {
    echo "2099-01-01T00:00:00Z|${CONST_HASH}|poison.yaml" > "$PICKUP_DEDUP_LOG"
    local f="$TEST_TEMP_DIR/empty.yaml"
    printf 'pickup_id: P-002\nversion: 1\n' > "$f"
    run pickup_dedup_check "$f"
    [ "$status" -eq 1 ]
}

@test "create_inception: empty summary/project refuses and creates no task" {
    local f="$TEST_TEMP_DIR/blank.yaml"
    _envelope "$f" "" ""
    run pickup_create_inception "$f"
    [ "$status" -eq 1 ]
    [[ "$output" == *"payload.summary, source.project"* ]]
    [ ! -s "$FW_CALLS" ]
}

@test "process_one: refused creation leaves envelope in inbox, no dedup row, not processed" {
    local f="$PICKUP_INBOX/blank.yaml"
    _envelope "$f" "" ""
    run pickup_process_one "$f"
    [ "$status" -eq 1 ]
    [ -f "$f" ]
    [ ! -e "$PICKUP_PROCESSED/blank.yaml" ]
    [ ! -s "$PICKUP_DEDUP_LOG" ]
    [ ! -s "$FW_CALLS" ]
}

@test "process_one: a valid envelope still creates a task and records dedup" {
    local f="$PICKUP_INBOX/good.yaml"
    _envelope "$f" "Real summary" "proj-a"
    run pickup_process_one "$f"
    [ "$status" -eq 0 ]
    grep -q "Pickup: Real summary (from proj-a)" "$FW_CALLS"
    [ -s "$PICKUP_DEDUP_LOG" ]
    [ ! -f "$f" ]
}
