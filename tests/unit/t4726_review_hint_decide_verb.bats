#!/usr/bin/env bats
# T-4726: `fw task review` on an inception prints a CLI fallback
#   fw inception decide <id> <verb> --rationale "<Recommendation text>"
# The verb was hard-coded to `go`, so a NO-GO recommendation produced a
# ready-to-paste GO (TermLink T-2958: three NO-GO -> GO records). The verb now
# comes from the Recommendation's parsed verdict (web.shared.extract_recommendation);
# anything it cannot map prints the literal placeholder `go|no-go|defer`.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export WATCHTOWER_URL="http://localhost:3000"
    export NO_COLOR=1
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1 = task id, $2 = Recommendation section body
_make_inception() {
    cat > "$PROJECT_ROOT/.tasks/active/$1-test.md" <<EOF
---
id: $1
name: "Decide-verb hint test"
description: test
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
created: 2026-10-24T00:00:00Z
last_update: 2026-10-24T00:00:00Z
date_finished: null
---

# $1: Decide-verb hint test

## Acceptance Criteria

### Agent
- [x] Problem statement validated

### Human
- [ ] [REVIEW] Review

## Recommendation

$2
EOF
}

# Prints the decide line of the CLI hint (the line after "CLI:").
_decide_line() {
    cd "$PROJECT_ROOT"
    FW_ALLOW_UNREADY_HANDOFF=1 "$FRAMEWORK_ROOT/bin/fw" task review "$1" 2>/dev/null \
        | grep -E 'inception decide .*\\$' | sed -e 's/^[[:space:]]*//'
}

@test "T-4726: GO recommendation -> decide go" {
    _make_inception T-9701 "**Recommendation:** GO — build it

**Rationale:** the evidence supports it, measured on a fixture."
    run _decide_line T-9701
    [ "$status" -eq 0 ]
    [[ "$output" == *"inception decide T-9701 go \\" ]]
}

@test "T-4726: NO-GO recommendation -> decide no-go, never go" {
    _make_inception T-9702 "**Recommendation:** NO-GO — demand has not materialised

**Rationale:** nobody asked for it in three months of field use."
    run _decide_line T-9702
    [ "$status" -eq 0 ]
    [[ "$output" == *"inception decide T-9702 no-go \\" ]]
}

@test "T-4726: DEFER recommendation -> decide defer" {
    _make_inception T-9703 "**Recommendation:** DEFER — waiting on the upstream fix

**Rationale:** the dependency ships next release; a spike is pointless before it."
    run _decide_line T-9703
    [ "$status" -eq 0 ]
    [[ "$output" == *"inception decide T-9703 defer \\" ]]
}

@test "T-4726: bulleted, bold-wrapped, lowercase NO-GO -> decide no-go" {
    _make_inception T-9704 "- **Recommendation:** **no-go** — not worth it

- **Rationale:** the cost outweighs the measured benefit on this corpus."
    run _decide_line T-9704
    [ "$status" -eq 0 ]
    [[ "$output" == *"inception decide T-9704 no-go \\" ]]
}

@test "T-4726: unparseable verdict -> literal go|no-go|defer placeholder" {
    _make_inception T-9705 "**Recommendation:** SHIP IT maybe

**Rationale:** the author never wrote a verdict token the parser knows."
    run _decide_line T-9705
    [ "$status" -eq 0 ]
    [[ "$output" == *"inception decide T-9705 go|no-go|defer \\" ]]
}

@test "T-4726: no Recommendation line -> placeholder and the fallback note" {
    _make_inception T-9706 "The author wrote prose here but never a Recommendation line at all, which is long enough to count as content."
    cd "$PROJECT_ROOT"
    run bash -c 'FW_ALLOW_UNREADY_HANDOFF=1 FW_ALLOW_EMPTY_RECOMMENDATION=1 "$FRAMEWORK_ROOT/bin/fw" task review T-9706 2>&1'
    [[ "$output" == *"inception decide T-9706 go|no-go|defer \\"* ]]
    [[ "$output" == *"No \`**Recommendation:**\` line found"* ]]
    [[ "$output" != *"inception decide T-9706 go \\"* ]]
}
