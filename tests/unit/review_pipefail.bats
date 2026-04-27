#!/usr/bin/env bats
# T-1545 — Regression: fw task review must not silent-exit-1 on inception
# tasks with empty/template-only ## Recommendation sections.
#
# Origin: 003-NTB-ATC-Plugin T-203. lib/review.sh used a sed|grep -v|...|head
# pipeline that exited 1 when every grep -v filtered all input. Under
# `set -e -o pipefail` (set in bin/fw) this aborted emit_review silently:
# exit 1, empty stdout/stderr, no review marker, locked inception-decide gate.
#
# Behavior under fix: WARNING goes to stderr; URL/QR/marker still print;
# exit 0; review marker created in .context/working/.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export WATCHTOWER_URL="http://localhost:3000"
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build an inception task file. $1 = task_id, $2 = recommendation block content
# (everything between '## Recommendation' and EOF — empty string means empty section).
_make_inception() {
    local task_id="$1"
    local rec_body="$2"
    local file="$PROJECT_ROOT/.tasks/active/${task_id}-test.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "Test inception"
description: test
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
created: 2026-04-27T00:00:00Z
last_update: 2026-04-27T00:00:00Z
date_finished: null
---

# ${task_id}: Test

## Acceptance Criteria

### Human
- [ ] [REVIEW] Review

## Recommendation

${rec_body}
EOF
    echo "$file"
}

@test "empty Recommendation: WARNING fires AND exit 0 AND marker created" {
    cd "$PROJECT_ROOT"
    _make_inception "T-9001" "" >/dev/null

    run "$FRAMEWORK_ROOT/bin/fw" task review T-9001
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: No substantive ## Recommendation"* ]]
    [[ "$output" == *"Inception Review: T-9001"* ]]
    [ -f "$PROJECT_ROOT/.context/working/.reviewed-T-9001" ]
}

@test "template-only Recommendation (multi-line HTML comment): WARNING fires AND exit 0" {
    cd "$PROJECT_ROOT"
    local placeholder='<!-- REQUIRED before fw inception decide. Write your recommendation here.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why
-->'
    _make_inception "T-9002" "$placeholder" >/dev/null

    run "$FRAMEWORK_ROOT/bin/fw" task review T-9002
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: No substantive ## Recommendation"* ]]
    [ -f "$PROJECT_ROOT/.context/working/.reviewed-T-9002" ]
}

@test "substantive Recommendation: NO warning, exit 0, marker created" {
    cd "$PROJECT_ROOT"
    local rec='**Recommendation:** GO

**Rationale:** Spike validated all four assumptions; build is mechanical.

**Evidence:**
- Finding 1
- Finding 2'
    _make_inception "T-9003" "$rec" >/dev/null

    run "$FRAMEWORK_ROOT/bin/fw" task review T-9003
    [ "$status" -eq 0 ]
    [[ "$output" != *"WARNING: No substantive"* ]]
    [[ "$output" == *"Inception Review: T-9003"* ]]
    [ -f "$PROJECT_ROOT/.context/working/.reviewed-T-9003" ]
}

@test "empty Recommendation must NOT exit 1 with silent stdout/stderr (T-1545 origin)" {
    cd "$PROJECT_ROOT"
    _make_inception "T-9004" "" >/dev/null

    # Run twice — once capturing combined output, once capturing exit code only —
    # to assert both invariants hold simultaneously.
    run "$FRAMEWORK_ROOT/bin/fw" task review T-9004
    [ "$status" -eq 0 ]
    # stdout/stderr combined must NOT be empty (the silent-failure symptom)
    [ -n "$output" ]
}
