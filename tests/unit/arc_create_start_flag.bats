#!/usr/bin/env bats
# T-1852 counter-proposal: `fw arc create --start` one-step convenience.
# Default behaviour writes `status: draft`; --start writes `status: in-progress`.
# Preserves backwards-compat for "create + immediately work" muscle memory
# while keeping the draft state reachable as the default.

#
# T-4523: the arcs are created in a throwaway project, not the framework repo.
# Run from the checkout, each test wrote .context/arcs/t1852-*.yaml into it (and,
# with a caller's PROJECT_ROOT exported, into THAT project, where teardown never
# looked). cwd is the fixture, so the relative paths below read the fixture.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    TEST_ROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.context/working" \
        "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_ROOT/.framework.yaml"
    export PROJECT_ROOT="$TEST_ROOT"
    cd "$TEST_ROOT"
    ARC_DEFAULT="t1852-default-$$"
    ARC_START="t1852-start-$$"
    LIVE_ARCS="$(ls "$FRAMEWORK_ROOT/.context/arcs" 2>/dev/null | grep '^t1852-' || true)"
}

teardown() {
    # The point of the fixture: no t1852 arc appears in the framework's own arcs dir.
    [ "$(ls "$FRAMEWORK_ROOT/.context/arcs" 2>/dev/null | grep '^t1852-' || true)" = "$LIVE_ARCS" ]
}

@test "fw arc create without --start writes status: draft" {
    run "$FRAMEWORK_ROOT/bin/fw" arc create "$ARC_DEFAULT" \
        --name "default smoke" \
        --headline-mechanic "user runs default create and observes draft state firing on the page in full view"
    [ "$status" -eq 0 ]
    [ -f ".context/arcs/${ARC_DEFAULT}.yaml" ]
    status_line=$(grep '^status:' ".context/arcs/${ARC_DEFAULT}.yaml")
    [ "$status_line" = "status: draft" ]
}

@test "fw arc create --start writes status: in-progress" {
    run "$FRAMEWORK_ROOT/bin/fw" arc create "$ARC_START" \
        --name "start smoke" \
        --headline-mechanic "user runs create with --start flag and observes in-progress state firing on the page in full view" \
        --start
    [ "$status" -eq 0 ]
    [ -f ".context/arcs/${ARC_START}.yaml" ]
    status_line=$(grep '^status:' ".context/arcs/${ARC_START}.yaml")
    [ "$status_line" = "status: in-progress" ]
}

@test "fw arc create --start output mentions one-step creation" {
    run "$FRAMEWORK_ROOT/bin/fw" arc create "$ARC_START" \
        --name "start smoke" \
        --headline-mechanic "user runs create with start flag and observes in-progress confirmation message firing on the page in full view" \
        --start
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "status: in-progress"
    echo "$output" | grep -q "created with --start"
}

@test "fw arc create default output still nudges to arc start" {
    run "$FRAMEWORK_ROOT/bin/fw" arc create "$ARC_DEFAULT" \
        --name "default smoke" \
        --headline-mechanic "user runs default create and observes the draft-state nudge firing on the page in full view"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "status: draft"
    echo "$output" | grep -q "use 'fw arc start"
}
