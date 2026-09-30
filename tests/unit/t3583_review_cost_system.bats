#!/usr/bin/env bats
# Tests for review cost logging and proposal system (T-3583)

setup() {
    export TESTDIR="$BATS_TEST_TMPDIR/t3583"
    mkdir -p "$TESTDIR"/.context/costs
    export PROJECT_ROOT="$TESTDIR"
    export FRAMEWORK_ROOT="/opt/999-Agentic-Engineering-Framework"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
}

@test "backend policy file exists at expected path" {
    [ -f "$FRAMEWORK_ROOT/policy/review-backends.yaml" ]
}

@test "backend policy declares internal and paid backends" {
    grep -q "cost_class: internal" "$FRAMEWORK_ROOT/policy/review-backends.yaml"
    grep -q "cost_class: paid" "$FRAMEWORK_ROOT/policy/review-backends.yaml"
}

@test "backend policy declares openrouter as paid" {
    grep -A 3 "id: openrouter" "$FRAMEWORK_ROOT/policy/review-backends.yaml" | grep -q "cost_class: paid"
    grep -A 4 "id: openrouter" "$FRAMEWORK_ROOT/policy/review-backends.yaml" | grep -q "approval_required: true"
}

@test "backend policy declares claude-code as internal" {
    grep -A 3 "id: claude-code" "$FRAMEWORK_ROOT/policy/review-backends.yaml" | grep -q "cost_class: internal"
    grep -A 4 "id: claude-code" "$FRAMEWORK_ROOT/policy/review-backends.yaml" | grep -q "approval_required: false"
}

@test "cost.sh library exists and is sourced correctly" {
    source "$FW_LIB_DIR/cost.sh"
    type cost_log_review | grep -q "is a function"
}

@test "cost_init creates the ledger directory" {
    source "$FW_LIB_DIR/cost.sh"
    cost_init
    [ -d "$PROJECT_ROOT/.context/costs" ]
}

@test "cost_validate_backend accepts known backends" {
    source "$FW_LIB_DIR/cost.sh"
    run cost_validate_backend "claude-code"
    [ "$status" -eq 0 ]
    
    run cost_validate_backend "codex"
    [ "$status" -eq 0 ]
}

@test "cost_validate_backend rejects unknown backends" {
    source "$FW_LIB_DIR/cost.sh"
    run cost_validate_backend "fake-backend"
    [ "$status" -ne 0 ]
}

@test "cost_get_backend_class returns correct class" {
    source "$FW_LIB_DIR/cost.sh"
    result=$(cost_get_backend_class "openrouter")
    [ "$result" = "paid" ]
}

@test "cost_backend_needs_approval correctly identifies paid backends" {
    source "$FW_LIB_DIR/cost.sh"
    run cost_backend_needs_approval "openrouter"
    [ "$status" -eq 0 ]
    
    run cost_backend_needs_approval "claude-code"
    [ "$status" -ne 0 ]
}

@test "review.sh library exists and exports review_main" {
    source "$FW_LIB_DIR/review.sh"
    type review_main | grep -q "is a function"
}

@test "fw review list-backends displays available backends" {
    cd "$TESTDIR"
    run "$FRAMEWORK_ROOT/lib/review.sh" list-backends
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backend"* || "$output" == *"claude-code"* ]]
}

@test "cost ledger file is created on first write" {
    cd "$TESTDIR"
    export PROJECT_ROOT="$TESTDIR"
    source "$FW_LIB_DIR/cost.sh"
    cost_log_review --task T-001 --backend claude-code --purpose "test"
    [ -f "$TESTDIR/.context/costs/reviews.jsonl" ]
}

@test "ledger entries contain expected fields" {
    cd "$TESTDIR"
    export PROJECT_ROOT="$TESTDIR"
    source "$FW_LIB_DIR/cost.sh"
    cost_log_review --task T-002 --backend codex --purpose "code-review"
    
    grep -q '"task": "T-002"' "$TESTDIR/.context/costs/reviews.jsonl"
    grep -q '"backend": "codex"' "$TESTDIR/.context/costs/reviews.jsonl"
    grep -q '"class": "internal"' "$TESTDIR/.context/costs/reviews.jsonl"
    grep -q '"purpose": "code-review"' "$TESTDIR/.context/costs/reviews.jsonl"
}

