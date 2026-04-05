#!/usr/bin/env bats
# Unit tests for lib/upstream.sh — upstream issue reporting
# Origin: T-915

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_DIR="$BATS_TMPDIR/fw_upstream_test_$$"
    mkdir -p "$TEST_DIR"
    export PROJECT_ROOT="$TEST_DIR"
    export FRAMEWORK_ROOT

    # Create minimal .framework.yaml
    cat > "$TEST_DIR/.framework.yaml" << 'EOF'
project_name: test-project
version: 1.0.0
upstream_repo: TestOwner/TestRepo
EOF

    # Source upstream.sh (it uses set -euo pipefail, so we source carefully)
    # We need to prevent it from sourcing paths.sh which may fail outside framework
    # Instead, source the functions directly by extracting them
    (
        # Temporarily override set -euo pipefail and source
        set +euo pipefail 2>/dev/null || true
        source "$FRAMEWORK_ROOT/lib/upstream.sh" 2>/dev/null
    ) || true

    # Source with relaxed error handling
    set +euo pipefail 2>/dev/null || true
    source "$FRAMEWORK_ROOT/lib/upstream.sh" 2>/dev/null || true
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- _upstream_resolve_repo ---

@test "resolve_repo reads from .framework.yaml" {
    result=$(_upstream_resolve_repo)
    [ "$result" = "TestOwner/TestRepo" ]
}

@test "resolve_repo falls through to git remote when no yaml" {
    rm "$TEST_DIR/.framework.yaml"
    # With no yaml, it falls through to git remote detection
    # In test env, FRAMEWORK_ROOT points to real repo so it finds the remote
    run bash -c "
        export PROJECT_ROOT='$TEST_DIR'
        export FRAMEWORK_ROOT='$TEST_DIR'
        set +euo pipefail
        source '$FRAMEWORK_ROOT/lib/upstream.sh' 2>/dev/null
        _upstream_resolve_repo
    "
    # Should succeed (exit 0) — may return empty or a detected remote
    [ "$status" -eq 0 ]
}

@test "resolve_repo ignores empty upstream_repo line" {
    echo "upstream_repo:" > "$TEST_DIR/.framework.yaml"
    result=$(_upstream_resolve_repo)
    # Should fall through to git remote detection
    # In test env without git, may return framework's repo or empty
    # Just verify it doesn't crash
    [ "$?" -eq 0 ]
}

# --- _upstream_is_sent / _upstream_mark_sent ---

@test "is_sent returns false when no sent file" {
    run _upstream_is_sent "Some title"
    [ "$status" -ne 0 ]
}

@test "mark_sent creates sent file and records entry" {
    _upstream_mark_sent "Bug: test issue" "https://github.com/test/repo/issues/1"
    local sent_file
    sent_file=$(_upstream_sent_file)
    [ -f "$sent_file" ]
    grep -q "Bug: test issue" "$sent_file"
    grep -q "issues/1" "$sent_file"
}

@test "is_sent returns true after mark_sent" {
    _upstream_mark_sent "Bug: test issue" "https://github.com/test/repo/issues/1"
    _upstream_is_sent "Bug: test issue"
}

@test "is_sent returns false for different title" {
    _upstream_mark_sent "Bug: test issue" "https://github.com/test/repo/issues/1"
    run _upstream_is_sent "Bug: other issue"
    [ "$status" -ne 0 ]
}

@test "mark_sent appends multiple entries" {
    _upstream_mark_sent "Issue 1" "https://github.com/test/repo/issues/1"
    _upstream_mark_sent "Issue 2" "https://github.com/test/repo/issues/2"
    local sent_file
    sent_file=$(_upstream_sent_file)
    local count
    count=$(wc -l < "$sent_file")
    [ "$count" -eq 2 ]
}

# --- _upstream_sent_file ---

@test "sent_file uses PROJECT_ROOT" {
    result=$(_upstream_sent_file)
    [[ "$result" == "$TEST_DIR/.context/working/.upstream-issues-sent" ]]
}

# --- do_upstream_config ---

@test "config show displays repo" {
    run do_upstream_config
    [ "$status" -eq 0 ]
    [[ "$output" == *"TestOwner/TestRepo"* ]]
}

@test "config set validates repo format" {
    run do_upstream_config --repo "invalid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid repo format"* ]]
}

@test "config set accepts valid format" {
    do_upstream_config --repo "NewOwner/NewRepo"
    grep -q "upstream_repo: NewOwner/NewRepo" "$TEST_DIR/.framework.yaml"
}

@test "config set updates existing upstream_repo" {
    do_upstream_config --repo "Updated/Repo"
    result=$(grep '^upstream_repo:' "$TEST_DIR/.framework.yaml" | sed 's/upstream_repo: *//')
    [ "$result" = "Updated/Repo" ]
}

@test "config set creates .framework.yaml if missing" {
    rm "$TEST_DIR/.framework.yaml"
    do_upstream_config --repo "Fresh/Repo"
    [ -f "$TEST_DIR/.framework.yaml" ]
    grep -q "upstream_repo: Fresh/Repo" "$TEST_DIR/.framework.yaml"
}

# --- do_upstream routing ---

@test "upstream help shows usage" {
    run do_upstream help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw upstream"* ]]
    [[ "$output" == *"report"* ]]
}

@test "upstream empty shows help" {
    run do_upstream ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw upstream"* ]]
}

@test "upstream unknown subcommand fails" {
    run do_upstream nonexistent
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown"* ]]
}

@test "upstream status calls config" {
    run do_upstream status
    [ "$status" -eq 0 ]
    [[ "$output" == *"TestOwner/TestRepo"* ]]
}

# --- do_upstream_report validation ---

@test "report fails without title" {
    run do_upstream_report
    [ "$status" -ne 0 ]
    [[ "$output" == *"--title is required"* ]]
}

@test "report fails without gh cli" {
    # Only test this if gh is actually missing or we can hide it
    if ! command -v gh &>/dev/null; then
        run do_upstream_report --title "Test"
        [ "$status" -ne 0 ]
        [[ "$output" == *"gh CLI"* ]]
    else
        skip "gh CLI is installed — cannot test missing-gh path"
    fi
}

# --- do_upstream_list ---

@test "list shows no issues when empty" {
    run do_upstream_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No upstream issues"* ]]
}

@test "list shows sent issues" {
    _upstream_mark_sent "Test Issue" "https://github.com/test/repo/issues/42"
    run do_upstream_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test Issue"* ]]
    [[ "$output" == *"issues/42"* ]]
}
