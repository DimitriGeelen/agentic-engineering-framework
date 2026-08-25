#!/usr/bin/env bats
# T-1716 Stream C: do_inception_retrofit_recommendations
#
# Tests:
#   - read-only by default (no file mutation)
#   - --apply mutates files; injects DEFER stub
#   - real-Recommendation tasks left alone
#   - non-inception tasks left alone
#   - clean repo (no stale inceptions) — no-op exit 0

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    unset CLAUDECODE
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
    mkdir -p "$TEST_TEMP_DIR/.tasks/active"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_template_only() {
    local tid="$1"
    cat > "$TEST_TEMP_DIR/.tasks/active/${tid}-stub.md" << EOF
---
id: ${tid}
name: "stub"
workflow_type: inception
status: started-work
owner: human
---

# ${tid}: stub

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why
     **Evidence:**
     - Finding 1
-->

## Decisions

EOF
}

_make_real_recommendation() {
    local tid="$1"
    cat > "$TEST_TEMP_DIR/.tasks/active/${tid}-real.md" << EOF
---
id: ${tid}
name: "real"
workflow_type: inception
status: started-work
owner: human
---

# ${tid}: real

## Recommendation

**Recommendation:** GO

**Rationale:** Real reasoning here.

**Evidence:**
- Finding 1

## Decisions

EOF
}

@test "retrofit-rec: clean repo → no-op + green message" {
    run do_inception_retrofit_recommendations
    [ "$status" -eq 0 ]
    [[ "$output" == *"No active inceptions need Recommendation retrofit"* ]]
}

@test "retrofit-rec: lists template-only tasks (read-only)" {
    _make_template_only T-9001
    _make_template_only T-9002
    run do_inception_retrofit_recommendations
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" == *"T-9002"* ]]
    [[ "$output" == *"read-only"* ]]
    [[ "$output" == *"--apply"* ]]
}

@test "retrofit-rec: read-only mode does NOT mutate file" {
    _make_template_only T-9001
    local before
    before=$(md5sum "$TEST_TEMP_DIR/.tasks/active/T-9001-stub.md" | awk '{print $1}')
    run do_inception_retrofit_recommendations
    [ "$status" -eq 0 ]
    local after
    after=$(md5sum "$TEST_TEMP_DIR/.tasks/active/T-9001-stub.md" | awk '{print $1}')
    [ "$before" = "$after" ]
}

@test "retrofit-rec --apply: injects DEFER stub" {
    _make_template_only T-9001
    run do_inception_retrofit_recommendations --apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"WROTE: DEFER stub"* ]] || [[ "$output" == *"Retrofit applied"* ]]
    grep -q "^\*\*Recommendation:\*\* DEFER" "$TEST_TEMP_DIR/.tasks/active/T-9001-stub.md"
    if grep -q "REQUIRED before fw inception decide" "$TEST_TEMP_DIR/.tasks/active/T-9001-stub.md"; then false; fi
    grep -q "T-1716" "$TEST_TEMP_DIR/.tasks/active/T-9001-stub.md"
}

@test "retrofit-rec --apply: leaves real-Recommendation tasks alone" {
    _make_real_recommendation T-9100
    local before
    before=$(md5sum "$TEST_TEMP_DIR/.tasks/active/T-9100-real.md" | awk '{print $1}')
    run do_inception_retrofit_recommendations --apply
    [ "$status" -eq 0 ]
    local after
    after=$(md5sum "$TEST_TEMP_DIR/.tasks/active/T-9100-real.md" | awk '{print $1}')
    [ "$before" = "$after" ]
    # Real Recommendation still GO
    grep -q "^\*\*Recommendation:\*\* GO" "$TEST_TEMP_DIR/.tasks/active/T-9100-real.md"
}

@test "retrofit-rec --apply: ignores non-inception tasks" {
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9200-build.md" << 'EOF'
---
id: T-9200
workflow_type: build
status: started-work
---
# T-9200: build
## Recommendation

<!-- template -->

## Decisions
EOF
    local before
    before=$(md5sum "$TEST_TEMP_DIR/.tasks/active/T-9200-build.md" | awk '{print $1}')
    run do_inception_retrofit_recommendations --apply
    [ "$status" -eq 0 ]
    local after
    after=$(md5sum "$TEST_TEMP_DIR/.tasks/active/T-9200-build.md" | awk '{print $1}')
    [ "$before" = "$after" ]
}

@test "retrofit-rec: --help prints usage" {
    run do_inception_retrofit_recommendations --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"retrofit-rec"* ]]
    [[ "$output" == *"--apply"* ]]
    [[ "$output" == *"T-1716"* ]]
}

@test "retrofit-rec: routed via do_inception" {
    _make_template_only T-9001
    run do_inception retrofit-rec
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
}

@test "retrofit-rec: alias retrofit-recommendations also routes" {
    _make_template_only T-9001
    run do_inception retrofit-recommendations
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-9001"* ]]
}

@test "retrofit-rec --apply: rationale mentions pre-T-1716 gate" {
    _make_template_only T-9001
    run do_inception_retrofit_recommendations --apply
    [ "$status" -eq 0 ]
    grep -q "pre-T-1716 gate" "$TEST_TEMP_DIR/.tasks/active/T-9001-stub.md"
}
