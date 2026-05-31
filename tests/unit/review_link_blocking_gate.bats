#!/usr/bin/env bats
# T-2139 V1 keystone — emit_review blocking gate on review-link homework.
#
# Verifies the integration between lib/review.sh:emit_review and the
# lib/review_link_validator.py --enforce mode shipped under T-2138 GO.
#
# Contract:
#   1. emit_review BLOCKS (return 2) on review-link homework with --enforce
#   2. emit_review PASSES on a clean task
#   3. FW_ALLOW_REVIEW_LINK_HOMEWORK=1 bypasses the block and writes a Tier-2 log

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/review.sh"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
    # Pin a base_url so the validator doesn't need a running Watchtower.
    echo "http://192.168.10.107:3000" > "$TEST_TEMP_DIR/.context/working/watchtower.url"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_write_task() {
    local task_id="$1"
    local workflow="$2"
    local body="$3"
    local file="$TEST_TEMP_DIR/.tasks/active/${task_id}-test.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test task"
status: work-completed
workflow_type: ${workflow}
owner: human
---

# ${task_id}: Test task

${body}
EOF
    echo "$file"
}

@test "emit_review blocks on URL-from-bin/fw watchtower homework (inception)" {
    local file
    file=$(_write_task "T-9991" "inception" "## Acceptance Criteria
### Human
- [ ] [REVIEW] open the pages
  **Steps:**
  1. Open these (URL from \`bin/fw watchtower url\`):
     - \`/\`
     - \`/bvp\`
")
    run emit_review "T-9991" "$file"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "BLOCKED: Review-handoff homework detected"
}

@test "emit_review block message names inception class for inception tasks" {
    local file
    file=$(_write_task "T-9992" "inception" "## Acceptance Criteria
### Human
- [ ] [REVIEW] open
  **Steps:**
  1. (URL from \`bin/fw watchtower url\`) — /foo
")
    run emit_review "T-9992" "$file"
    [ "$status" -eq 2 ]
    # The validator's class-aware hint goes to stderr, which bats merges into $output
    echo "$output" | grep -qi "inception"
    echo "$output" | grep -q "/inception/T-9992"
}

@test "emit_review block message names review class for build tasks" {
    local file
    file=$(_write_task "T-9993" "build" "## Acceptance Criteria
### Human
- [ ] [REVIEW] open
  **Steps:**
  1. (URL from \`bin/fw watchtower url\`) — /foo
")
    run emit_review "T-9993" "$file"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "/review/T-9993"
}

@test "emit_review passes a clean inception task" {
    local file
    file=$(_write_task "T-9994" "inception" "## Acceptance Criteria
### Human
- [ ] [REVIEW] open the page
  **Steps:**
  1. Open http://192.168.10.107:3000/inception/T-9994

## Recommendation
**Recommendation:** GO
Substantive rationale text spanning enough characters to pass the substantive-recommendation guard.
")
    run emit_review "T-9994" "$file"
    [ "$status" -eq 0 ] || { echo "stdout/err: $output"; false; }
}

@test "FW_ALLOW_REVIEW_LINK_HOMEWORK=1 bypasses block + logs Tier-2" {
    local file
    file=$(_write_task "T-9995" "build" "## Acceptance Criteria
### Human
- [ ] [REVIEW] open
  **Steps:**
  1. Open (URL from \`bin/fw watchtower url\`)/foo
")
    FW_ALLOW_REVIEW_LINK_HOMEWORK=1 run emit_review "T-9995" "$file"
    [ "$status" -eq 0 ]
    # Bypass log entry must exist
    local log="$TEST_TEMP_DIR/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "review-link-homework" "$log"
    grep -q "T-9995" "$log"
}
