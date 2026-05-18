#!/usr/bin/env bats
# T-1852 counter-proposal: `fw arc create --start` one-step convenience.
# Default behaviour writes `status: draft`; --start writes `status: in-progress`.
# Preserves backwards-compat for "create + immediately work" muscle memory
# while keeping the draft state reachable as the default.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    cd "$FRAMEWORK_ROOT"
    ARC_DEFAULT="t1852-default-$$"
    ARC_START="t1852-start-$$"
}

teardown() {
    rm -f ".context/arcs/${ARC_DEFAULT}.yaml" ".context/arcs/${ARC_START}.yaml"
}

@test "fw arc create without --start writes status: draft" {
    run bin/fw arc create "$ARC_DEFAULT" \
        --name "default smoke" \
        --headline-mechanic "user runs default create and observes draft state firing on the page in full view"
    [ "$status" -eq 0 ]
    [ -f ".context/arcs/${ARC_DEFAULT}.yaml" ]
    status_line=$(grep '^status:' ".context/arcs/${ARC_DEFAULT}.yaml")
    [ "$status_line" = "status: draft" ]
}

@test "fw arc create --start writes status: in-progress" {
    run bin/fw arc create "$ARC_START" \
        --name "start smoke" \
        --headline-mechanic "user runs create with --start flag and observes in-progress state firing on the page in full view" \
        --start
    [ "$status" -eq 0 ]
    [ -f ".context/arcs/${ARC_START}.yaml" ]
    status_line=$(grep '^status:' ".context/arcs/${ARC_START}.yaml")
    [ "$status_line" = "status: in-progress" ]
}

@test "fw arc create --start output mentions one-step creation" {
    run bin/fw arc create "$ARC_START" \
        --name "start smoke" \
        --headline-mechanic "user runs create with start flag and observes in-progress confirmation message firing on the page in full view" \
        --start
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "status: in-progress"
    echo "$output" | grep -q "created with --start"
}

@test "fw arc create default output still nudges to arc start" {
    run bin/fw arc create "$ARC_DEFAULT" \
        --name "default smoke" \
        --headline-mechanic "user runs default create and observes the draft-state nudge firing on the page in full view"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "status: draft"
    echo "$output" | grep -q "use 'fw arc start"
}
