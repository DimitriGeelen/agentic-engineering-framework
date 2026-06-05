#!/usr/bin/env bats
# T-1545 (origin) + T-2206 (upgrade) — fw task review behavior on inception
# tasks with empty/template-only ## Recommendation sections.
#
# T-1545 origin: lib/review.sh used a sed|grep -v|...|head pipeline that exited 1
# when every grep -v filtered all input. Under `set -e -o pipefail` (set in bin/fw)
# this aborted emit_review silently: exit 1, empty stdout/stderr, no review marker,
# locked inception-decide gate. T-1545 fix: WARNING to stderr, exit 0, marker created.
#
# T-2206 upgrade: empty/template-only ## Recommendation now BLOCKS by default
# (exit 1 with LOUD block message) per T-2204 GO consumer-side parity. The T-1545
# invariant survives: exit MUST NOT be silent. The bypass FW_ALLOW_EMPTY_RECOMMENDATION=1
# restores the warn-and-continue path.
#
# Contract under T-2206:
#   - empty ## Recommendation  → exit 1 + loud BLOCK message + Tier-2 hint
#   - empty + FW_ALLOW_EMPTY_RECOMMENDATION=1 → exit 0 + NOTE + bypass log
#   - substantive ## Recommendation → exit 0 + URL/QR/marker (unchanged)

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

@test "T-2206: empty Recommendation BLOCKS (exit 1) with loud stderr" {
    cd "$PROJECT_ROOT"
    _make_inception "T-9001" "" >/dev/null

    run "$FRAMEWORK_ROOT/bin/fw" task review T-9001
    [ "$status" -eq 1 ]
    # The new BLOCK message must name the env-var bypass.
    [[ "$output" == *"BLOCKED: Inception T-9001 has empty"* ]]
    [[ "$output" == *"FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    # Origin cross-refs must be present (T-679 governance + T-2204 chain).
    [[ "$output" == *"T-679"* ]] || [[ "$output" == *"T-2204"* ]]
    # No review marker on a blocked emission.
    [ ! -f "$PROJECT_ROOT/.context/working/.reviewed-T-9001" ]
}

@test "T-2206: template-only Recommendation BLOCKS (exit 1)" {
    cd "$PROJECT_ROOT"
    local placeholder='<!-- REQUIRED before fw inception decide. Write your recommendation here.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why
-->'
    _make_inception "T-9002" "$placeholder" >/dev/null

    run "$FRAMEWORK_ROOT/bin/fw" task review T-9002
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED: Inception T-9002 has empty"* ]]
    [ ! -f "$PROJECT_ROOT/.context/working/.reviewed-T-9002" ]
}

@test "substantive Recommendation: exit 0, marker created" {
    cd "$PROJECT_ROOT"
    local rec='**Recommendation:** GO

**Rationale:** Spike validated all four assumptions; build is mechanical.

**Evidence:**
- Finding 1
- Finding 2'
    _make_inception "T-9003" "$rec" >/dev/null

    run "$FRAMEWORK_ROOT/bin/fw" task review T-9003
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED: Inception"* ]]
    [[ "$output" == *"Inception Review: T-9003"* ]]
    [ -f "$PROJECT_ROOT/.context/working/.reviewed-T-9003" ]
}

@test "T-1545 invariant: empty Recommendation MUST NOT exit silently (loud BLOCK is fine)" {
    cd "$PROJECT_ROOT"
    _make_inception "T-9004" "" >/dev/null

    # T-1545 origin invariant: exit-1 with empty stdout/stderr is the bug.
    # T-2206 contract: exit 1 is now expected, but stderr MUST be loud.
    run "$FRAMEWORK_ROOT/bin/fw" task review T-9004
    [ "$status" -eq 1 ]
    # The T-1545 anti-symptom is silent failure; the test guards loudness, not
    # success. Merged stdout+stderr must NOT be empty.
    [ -n "$output" ]
    # Must contain the BLOCK keyword or block banner — never silent.
    [[ "$output" == *"BLOCKED"* ]]
}

@test "T-2206 bypass: FW_ALLOW_EMPTY_RECOMMENDATION=1 → exit 0 + NOTE + log" {
    cd "$PROJECT_ROOT"
    _make_inception "T-9005" "" >/dev/null

    FW_ALLOW_EMPTY_RECOMMENDATION=1 run "$FRAMEWORK_ROOT/bin/fw" task review T-9005
    [ "$status" -eq 0 ]
    # NOTE banner replaces the BLOCK banner under the bypass.
    [[ "$output" == *"NOTE: Inception T-9005 has empty"* ]] || [[ "$output" == *"emission allowed via FW_ALLOW_EMPTY_RECOMMENDATION=1"* ]]
    # Marker is created on the bypass path.
    [ -f "$PROJECT_ROOT/.context/working/.reviewed-T-9005" ]
    # Tier-2 log entry written.
    local log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "FW_ALLOW_EMPTY_RECOMMENDATION" "$log"
    grep -q "T-9005" "$log"
}
