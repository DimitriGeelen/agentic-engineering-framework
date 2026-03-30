#!/usr/bin/env bats
# Unit tests for lib/pickup.sh
#
# Tests pickup pipeline: validation, dedup, ID generation, processing

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    # Override pickup dirs to temp
    export PICKUP_DIR="$TEST_TEMP_DIR/.context/pickup"
    export PICKUP_INBOX="$PICKUP_DIR/inbox"
    export PICKUP_PROCESSED="$PICKUP_DIR/processed"
    export PICKUP_REJECTED="$PICKUP_DIR/rejected"
    export PICKUP_DEDUP_LOG="$PICKUP_DIR/dedup.log"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/pickup.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: create a valid pickup envelope
_create_envelope() {
    local file="$1"
    local pickup_type="${2:-bug-report}"
    local summary="${3:-Fix audit false fails}"
    local project="${4:-vinix24}"
    cat > "$file" <<EOF
pickup_id: P-001
version: 1
type: $pickup_type
source:
  project: "$project"
  task_id: "T-042"
  agent: "claude-code"
  timestamp: "2026-03-30T12:00:00Z"
payload:
  summary: "$summary"
  detail: "Multi-line explanation"
  evidence: "agents/audit/audit.sh:245"
  priority: high
  tags: [audit, validation]
EOF
}

# --- pickup_ensure_dirs ---

@test "pickup: pickup_ensure_dirs creates directories" {
    pickup_ensure_dirs
    [ -d "$PICKUP_INBOX" ]
    [ -d "$PICKUP_PROCESSED" ]
    [ -d "$PICKUP_REJECTED" ]
}

@test "pickup: pickup_ensure_dirs is idempotent" {
    pickup_ensure_dirs
    pickup_ensure_dirs
    [ -d "$PICKUP_INBOX" ]
}

# --- pickup_validate_envelope ---

@test "pickup: validate_envelope passes valid envelope" {
    local f="$TEST_TEMP_DIR/valid.yaml"
    _create_envelope "$f"
    run pickup_validate_envelope "$f"
    [ "$status" -eq 0 ]
}

@test "pickup: validate_envelope fails on missing file" {
    run pickup_validate_envelope "/nonexistent/file.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" == *"File not found"* ]]
}

@test "pickup: validate_envelope fails on missing version" {
    local f="$TEST_TEMP_DIR/no-version.yaml"
    cat > "$f" <<'EOF'
type: bug-report
source:
  project: "test"
payload:
  summary: "test"
EOF
    run pickup_validate_envelope "$f"
    [ "$status" -eq 1 ]
    [[ "$output" == *"version"* ]]
}

@test "pickup: validate_envelope fails on missing type" {
    local f="$TEST_TEMP_DIR/no-type.yaml"
    cat > "$f" <<'EOF'
version: 1
source:
  project: "test"
payload:
  summary: "test"
EOF
    run pickup_validate_envelope "$f"
    [ "$status" -eq 1 ]
    [[ "$output" == *"type"* ]]
}

@test "pickup: validate_envelope fails on missing source.project" {
    local f="$TEST_TEMP_DIR/no-project.yaml"
    cat > "$f" <<'EOF'
version: 1
type: bug-report
source:
  agent: "claude-code"
payload:
  summary: "test"
EOF
    run pickup_validate_envelope "$f"
    [ "$status" -eq 1 ]
    [[ "$output" == *"source.project"* ]]
}

@test "pickup: validate_envelope fails on missing payload.summary" {
    local f="$TEST_TEMP_DIR/no-summary.yaml"
    cat > "$f" <<'EOF'
version: 1
type: bug-report
source:
  project: "test"
payload:
  detail: "no summary here"
EOF
    run pickup_validate_envelope "$f"
    [ "$status" -eq 1 ]
    [[ "$output" == *"payload.summary"* ]]
}

@test "pickup: validate_envelope fails on invalid type" {
    local f="$TEST_TEMP_DIR/bad-type.yaml"
    cat > "$f" <<'EOF'
version: 1
type: invalid-type
source:
  project: "test"
payload:
  summary: "test"
EOF
    run pickup_validate_envelope "$f"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid type"* ]]
}

@test "pickup: validate_envelope accepts all valid types" {
    for t in bug-report learning feature-proposal pattern; do
        local f="$TEST_TEMP_DIR/type-$t.yaml"
        _create_envelope "$f" "$t"
        run pickup_validate_envelope "$f"
        [ "$status" -eq 0 ]
    done
}

# --- pickup_dedup_hash ---

@test "pickup: dedup_hash produces consistent hash" {
    local f="$TEST_TEMP_DIR/hash-test.yaml"
    _create_envelope "$f"
    local h1 h2
    h1=$(pickup_dedup_hash "$f")
    h2=$(pickup_dedup_hash "$f")
    [ "$h1" = "$h2" ]
    [ ${#h1} -eq 64 ]  # SHA256 = 64 hex chars
}

@test "pickup: dedup_hash differs for different summaries" {
    local f1="$TEST_TEMP_DIR/hash1.yaml"
    local f2="$TEST_TEMP_DIR/hash2.yaml"
    _create_envelope "$f1" "bug-report" "First summary"
    _create_envelope "$f2" "bug-report" "Second summary"
    local h1 h2
    h1=$(pickup_dedup_hash "$f1")
    h2=$(pickup_dedup_hash "$f2")
    [ "$h1" != "$h2" ]
}

@test "pickup: dedup_hash differs for different projects" {
    local f1="$TEST_TEMP_DIR/proj1.yaml"
    local f2="$TEST_TEMP_DIR/proj2.yaml"
    _create_envelope "$f1" "bug-report" "Same summary" "project-a"
    _create_envelope "$f2" "bug-report" "Same summary" "project-b"
    local h1 h2
    h1=$(pickup_dedup_hash "$f1")
    h2=$(pickup_dedup_hash "$f2")
    [ "$h1" != "$h2" ]
}

# --- pickup_dedup_check ---

@test "pickup: dedup_check returns 1 (not dup) when no log" {
    local f="$TEST_TEMP_DIR/dedup-test.yaml"
    _create_envelope "$f"
    run pickup_dedup_check "$f"
    [ "$status" -eq 1 ]
}

@test "pickup: dedup_check returns 0 (dup) after recording" {
    local f="$TEST_TEMP_DIR/dedup-test.yaml"
    _create_envelope "$f"
    pickup_ensure_dirs
    pickup_record_dedup "$f"
    run pickup_dedup_check "$f"
    [ "$status" -eq 0 ]
}

# --- pickup_next_id ---

@test "pickup: next_id returns P-001 on empty directories" {
    pickup_ensure_dirs
    local id
    id=$(pickup_next_id)
    [ "$id" = "P-001" ]
}

@test "pickup: next_id increments past existing" {
    pickup_ensure_dirs
    _create_envelope "$PICKUP_INBOX/pickup-001.yaml"
    # The file already has pickup_id: P-001
    local id
    id=$(pickup_next_id)
    [ "$id" = "P-002" ]
}

@test "pickup: next_id scans processed dir too" {
    pickup_ensure_dirs
    local f="$PICKUP_PROCESSED/pickup-005.yaml"
    cat > "$f" <<'EOF'
pickup_id: P-005
version: 1
type: bug-report
source:
  project: test
payload:
  summary: test
EOF
    local id
    id=$(pickup_next_id)
    [ "$id" = "P-006" ]
}

# --- do_pickup ---

@test "pickup: do_pickup --help shows usage" {
    run do_pickup --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw pickup"* ]]
    [[ "$output" == *"process"* ]]
    [[ "$output" == *"status"* ]]
    [[ "$output" == *"list"* ]]
}

@test "pickup: do_pickup with no args shows help" {
    run do_pickup ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw pickup"* ]]
}

@test "pickup: do_pickup rejects unknown command" {
    run do_pickup bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown pickup command"* ]]
}

@test "pickup: do_pickup status shows counts" {
    pickup_ensure_dirs
    run do_pickup status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inbox:"* ]]
    [[ "$output" == *"Processed:"* ]]
    [[ "$output" == *"Rejected:"* ]]
}

@test "pickup: do_pickup list shows empty inbox" {
    pickup_ensure_dirs
    run do_pickup list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inbox is empty"* ]]
}

@test "pickup: do_pickup list shows envelope" {
    pickup_ensure_dirs
    _create_envelope "$PICKUP_INBOX/test-pickup.yaml" "bug-report" "Fix the thing" "myproject"
    run do_pickup list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fix the thing"* ]]
    [[ "$output" == *"myproject"* ]]
}

@test "pickup: do_pickup process on empty inbox" {
    pickup_ensure_dirs
    run do_pickup process
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inbox is empty"* ]]
}

@test "pickup: do_pickup process --dry-run does not move files" {
    pickup_ensure_dirs
    _create_envelope "$PICKUP_INBOX/test-dry.yaml"
    run do_pickup process --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD PROCESS"* ]]
    # File should still be in inbox
    [ -f "$PICKUP_INBOX/test-dry.yaml" ]
}

@test "pickup: pickup_process_one rejects invalid envelope" {
    pickup_ensure_dirs
    local f="$PICKUP_INBOX/bad.yaml"
    echo "garbage" > "$f"
    run pickup_process_one "$f"
    [ "$status" -eq 1 ]
    # File should be moved to rejected
    [ -f "$PICKUP_REJECTED/bad.yaml" ]
    [ ! -f "$PICKUP_INBOX/bad.yaml" ]
}

@test "pickup: pickup_process_one dedup rejects duplicate" {
    pickup_ensure_dirs
    local f="$PICKUP_INBOX/dup.yaml"
    _create_envelope "$f"
    # Record first occurrence
    pickup_record_dedup "$f"
    run pickup_process_one "$f"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEDUP"* ]]
}
