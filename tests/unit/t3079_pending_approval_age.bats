#!/usr/bin/env bats
# T-3079: no rail detected a Tier 0 approval request left sitting unanswered.
# Pending cards (.context/approvals/pending-*.yaml) were read only by pull
# surfaces (/approvals, fw approvals pending); three sat unseen for months.
# lib/approval_queue_age.py is the shared age predicate; fw doctor and fw audit
# (enforcement section) WARN on cards older than APPROVAL_PENDING_WARN_HOURS.

load ../test_helper

MOD="$FRAMEWORK_ROOT/lib/approval_queue_age.py"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/audits" \
             "$PROJECT_ROOT/.context/approvals"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    APPROVALS="$PROJECT_ROOT/.context/approvals"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# write_card <name> <iso-timestamp> <kind>
write_card() {
    cat > "$APPROVALS/pending-$1.yaml" <<EOF
command_hash: $1
command_preview: 'echo hello from $1'
origin:
  kind: $3
risk: 'test risk'
status: pending
timestamp: '$2'
type: tier0
EOF
}

old_ts()   { date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ; }
fresh_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

@test "module: card older than threshold is listed with age, kind, preview" {
    write_card aaa111 "$(old_ts)" agent
    run python3 "$MOD" stale "$APPROVALS" 24
    [ "$status" -eq 0 ]
    [[ "$output" == pending-aaa111.yaml$'\t'7* ]]
    [[ "$output" == *$'\tagent\techo hello from aaa111'* ]]
}

@test "module: fresh card is not listed" {
    write_card bbb222 "$(fresh_ts)" agent
    run python3 "$MOD" stale "$APPROVALS" 24
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "module: malformed card is reported (age from mtime), never skipped" {
    printf 'timestamp: [unclosed\n  :: not yaml\n' > "$APPROVALS/pending-ccc333.yaml"
    touch -d '3 days ago' "$APPROVALS/pending-ccc333.yaml"
    run python3 "$MOD" stale "$APPROVALS" 24
    [ "$status" -eq 0 ]
    [[ "$output" == *"pending-ccc333.yaml"*"unreadable"* ]]
}

@test "module: missing approvals dir exits 1, bad threshold exits 2" {
    run python3 "$MOD" stale "$PROJECT_ROOT/nope" 24
    [ "$status" -eq 1 ]
    run python3 "$MOD" stale "$APPROVALS" notanumber
    [ "$status" -eq 2 ]
}

@test "module: resolved cards are ignored" {
    write_card ddd444 "$(old_ts)" agent
    mv "$APPROVALS/pending-ddd444.yaml" "$APPROVALS/resolved-ddd444.yaml"
    run python3 "$MOD" stale "$APPROVALS" 24
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "audit enforcement: stale card WARNs with remedy" {
    write_card eee555 "$(old_ts)" test
    run "$AUDIT" --section enforcement
    [[ "$output" == *"Tier 0 approval request unanswered for 7"*"(test): pending-eee555.yaml"* ]]
    [[ "$output" == *"bin/fw approvals expire"* ]]
}

@test "audit enforcement: fresh card only → PASS line, no WARN" {
    write_card fff666 "$(fresh_ts)" agent
    run "$AUDIT" --section enforcement
    [[ "$output" == *"No Tier 0 approval request pending over 24h"* ]]
    [[ "$output" != *"approval request unanswered"* ]]
}

@test "doctor: stale card WARNs, fresh-only dir reports OK" {
    write_card ggg777 "$(old_ts)" agent
    cd "$FRAMEWORK_ROOT"
    FW_DOCTOR_SMOKE=0 FW_DOCTOR_APPROVALS_DIR="$APPROVALS" run bin/fw doctor --quick
    [[ "$output" == *"Tier 0 approval request unanswered for 7"*"(agent): pending-ggg777.yaml"* ]]
    [[ "$output" == *"bin/fw approvals pending"* ]]
    rm "$APPROVALS/pending-ggg777.yaml"
    write_card hhh888 "$(fresh_ts)" agent
    FW_DOCTOR_SMOKE=0 FW_DOCTOR_APPROVALS_DIR="$APPROVALS" run bin/fw doctor --quick
    [[ "$output" == *"No Tier 0 approval request pending over 24h"* ]]
    [[ "$output" != *"approval request unanswered"* ]]
}
