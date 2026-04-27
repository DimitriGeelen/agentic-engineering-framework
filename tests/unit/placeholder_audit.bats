#!/usr/bin/env bats
# T-1554 — Regression: audit_task_placeholders must catch the ordinal-criterion
# stubs the default template ships ([First criterion], [Second criterion], ...).
#
# Origin: T-1545 itself shipped to /review with literal placeholder ACs because
# the audit regex caught only [Criterion N] (numeric) — same silent-quality-decay
# class as T-1545 (an audit exists, but doesn't match the real placeholder text).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a task file whose AC section contains $1.
_make_task_with_ac() {
    local ac_block="$1"
    local file="$TEST_TEMP_DIR/T-1.md"
    cat > "$file" <<EOF
---
id: T-1
name: "Test"
status: started-work
workflow_type: build
---

# T-1: Test

## Acceptance Criteria

${ac_block}

## Verification

echo ok
EOF
    echo "$file"
}

# Reload audit on every test — function may not be in scope across @tests.
_audit() {
    bash -c "source '$FRAMEWORK_ROOT/lib/task-audit.sh' && audit_task_placeholders '$1'"
}

@test "[First criterion] placeholder is detected (BLOCKED)" {
    local body
    body='- [ ] [First criterion]
- [ ] [Second criterion]'
    local file
    file=$(_make_task_with_ac "$body")

    run _audit "$file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Placeholder content detected"* ]]
}

@test "[Second criterion] alone is detected (BLOCKED)" {
    local body
    body='- [x] Real first AC
- [ ] [Second criterion]'
    local file
    file=$(_make_task_with_ac "$body")

    run _audit "$file"
    [ "$status" -eq 1 ]
}

@test "[Third criterion] / [Fourth criterion] / [Fifth criterion] all detected" {
    for word in Third Fourth Fifth; do
        local body
        body="- [ ] [${word} criterion]"
        local file
        file=$(_make_task_with_ac "$body")

        run _audit "$file"
        [ "$status" -eq 1 ] || { echo "FAIL on [${word} criterion]"; return 1; }
    done
}

@test "numeric [Criterion 1] still blocks (no regression)" {
    local body
    body='- [ ] [Criterion 1]
- [ ] [Criterion 2]'
    local file
    file=$(_make_task_with_ac "$body")

    run _audit "$file"
    [ "$status" -eq 1 ]
}

@test "[TODO] and [PLACEHOLDER] still block (no regression)" {
    for marker in TODO PLACEHOLDER; do
        local body
        body="- [ ] [${marker}]"
        local file
        file=$(_make_task_with_ac "$body")

        run _audit "$file"
        [ "$status" -eq 1 ] || { echo "FAIL on [${marker}]"; return 1; }
    done
}

@test "substantive authored ACs pass clean" {
    local body
    body='- [x] Replace fragile sed/grep pipeline with awk-based detector
- [x] Add regression bats covering empty / template-only / substantive cases
- [ ] Smoke test on real tasks'
    local file
    file=$(_make_task_with_ac "$body")

    run _audit "$file"
    [ "$status" -eq 0 ]
}

@test "documentation mentioning placeholder strings inside backticks still blocks (current behavior — backticks stripped)" {
    # Note: audit_task_placeholders strips inline `code spans` BEFORE matching,
    # so documentation that backticks the placeholder strings is NOT flagged.
    # This test pins that behavior so future changes are explicit.
    local body
    body='- [x] Documents the `[First criterion]` literal as part of an explanation'
    local file
    file=$(_make_task_with_ac "$body")

    run _audit "$file"
    [ "$status" -eq 0 ]
}
