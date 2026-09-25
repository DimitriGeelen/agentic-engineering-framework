#!/usr/bin/env bats
# `fw fabric drift` gains the divergent class — card vs source.
#
# The class exists because none of the four classes above it can see it. The
# card IS registered, its file DOES exist, its declared edges are NOT stale, and
# it is not under-populated (it has edges — just fewer than the source has
# imports). So the control that matters is the negative one: a fixture clean on
# every other axis that still gets flagged, and its twin that does not.
#
# The other load-bearing test here is the UNKNOWN path. A detector that cannot
# run must never be reported as "0 divergent" — that reading is the precise
# failure the section exists to abolish.
#
# Every fixture is built in a tmp project (L-599): the live corpus moves under
# the test for reasons unrelated to these rules.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB_DIR="$FRAMEWORK_ROOT/agents/fabric/lib"

setup() {
    TMP_PROJECT=$(mktemp -d)
    COMPONENTS_DIR="$TMP_PROJECT/.fabric/components"
    mkdir -p "$COMPONENTS_DIR" "$TMP_PROJECT/lib"
    printf '#!/bin/bash\nhelper() { :; }\n' > "$TMP_PROJECT/lib/helper.sh"
    printf '#!/bin/bash\nsource "$LIB_DIR/helper.sh"\n' > "$TMP_PROJECT/lib/consumer.sh"
    card lib/helper.sh ''
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

# card <location> <depends_on-yaml-flow>
card() {
    local loc="$1" deps="${2:-}"
    local slug="${loc//\//-}"
    {
        echo "id: $loc"
        echo "name: ${loc##*/}"
        echo "location: $loc"
        echo "subsystem: framework-core"
        echo 'purpose: "A sentence that says what this does."'
        if [ -n "$deps" ]; then
            echo "depends_on: $deps"
        else
            echo "depends_on: []"
        fi
        echo "depended_by: []"
    } > "$COMPONENTS_DIR/${slug%.sh}.yaml"
}

run_drift() {
    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR
    export LIB_DIR
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
    ensure_fabric_dirs() { :; }
    # shellcheck source=agents/fabric/lib/drift.sh
    source "$LIB_DIR/drift.sh"
    do_drift "$@"
}

@test "a card whose source imports more than it declares is divergent" {
    card lib/consumer.sh ''
    run run_drift --summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"Divergent cards (card vs source):"* ]]
    [[ "$output" == *"lib/consumer.sh → undeclared: lib/helper.sh"* ]]
    [[ "$output" == *"divergent: 1"* ]]
    [[ "$output" == *"divergent-edges: 1"* ]]
    [[ "$output" == *"bin/fw fabric enrich"* ]]
}

@test "control: a card that declares what its source imports is NOT divergent" {
    card lib/consumer.sh '[{target: lib/helper.sh, type: sources}]'
    run run_drift --summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"divergent: 0"* ]]
    [[ "$output" != *"undeclared:"* ]]
}

@test "a detector that cannot run reports UNKNOWN, never 0" {
    card lib/consumer.sh ''
    # Point LIB_DIR's enrich.py at a copy that exits non-zero. The section must
    # say UNKNOWN: with a bare `0` an operator cannot tell a clean corpus from a
    # broken reader, which is the whole reason the rc is captured.
    local shim
    shim=$(mktemp -d)
    cp "$LIB_DIR/drift.sh" "$shim/drift.sh"
    cp "$LIB_DIR/underpopulated.py" "$shim/underpopulated.py"
    cp "$LIB_DIR/expand_patterns.py" "$shim/expand_patterns.py" 2>/dev/null || true
    printf 'import sys\nsys.exit(3)\n' > "$shim/enrich.py"
    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR
    export LIB_DIR="$shim"
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
    ensure_fabric_dirs() { :; }
    source "$shim/drift.sh"
    run do_drift --summary
    [[ "$output" == *"UNKNOWN"* ]]
    [[ "$output" == *"This is NOT 'no divergence'"* ]]
    [[ "$output" == *"divergent: UNKNOWN"* ]]
    # And it must NOT claim zero.
    [[ "$output" != *"divergent: 0"* ]]
    rm -rf "$shim"
}

@test "exit status is 0 even when the detector fails — drift stays advisory" {
    card lib/consumer.sh ''
    local shim
    shim=$(mktemp -d)
    cp "$LIB_DIR/drift.sh" "$shim/drift.sh"
    cp "$LIB_DIR/underpopulated.py" "$shim/underpopulated.py"
    cp "$LIB_DIR/expand_patterns.py" "$shim/expand_patterns.py" 2>/dev/null || true
    printf 'import sys\nsys.exit(3)\n' > "$shim/enrich.py"
    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR
    export LIB_DIR="$shim"
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
    ensure_fabric_dirs() { :; }
    source "$shim/drift.sh"
    run do_drift
    [ "$status" -eq 0 ]
    rm -rf "$shim"
}

@test "a failing detector does not abort the function mid-section" {
    # Under the inherited `set -e` an uncaptured command substitution failure
    # kills do_drift after the header and before the summary. The summary line
    # is the evidence that the rest of the function still ran.
    card lib/consumer.sh ''
    local shim
    shim=$(mktemp -d)
    cp "$LIB_DIR/drift.sh" "$shim/drift.sh"
    cp "$LIB_DIR/underpopulated.py" "$shim/underpopulated.py"
    cp "$LIB_DIR/expand_patterns.py" "$shim/expand_patterns.py" 2>/dev/null || true
    printf 'import sys\nsys.exit(3)\n' > "$shim/enrich.py"
    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR
    export LIB_DIR="$shim"
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
    ensure_fabric_dirs() { :; }
    set -e
    source "$shim/drift.sh"
    run do_drift --summary
    [[ "$output" == *"Summary:"* ]]
    [[ "$output" == *"unregistered:"* ]]
    rm -rf "$shim"
}

@test "the four existing sections and every existing summary key survive" {
    card lib/consumer.sh ''
    run run_drift --summary
    [ "$status" -eq 0 ]
    # Section 1's header is conditional on a watch-patterns.yaml this fixture
    # does not have; its counter still has to appear in the summary keys below.
    [[ "$output" == *"Orphaned cards:"* ]]
    [[ "$output" == *"Stale edges:"* ]]
    [[ "$output" == *"Under-populated cards:"* ]]
    for key in "unregistered:" "orphaned:" "stale:" "under-populated:" \
               "under-populated-todo-purpose:" \
               "under-populated-unknown-subsystem:" \
               "under-populated-no-edges:"; do
        [[ "$output" == *"$key"* ]]
    done
}

@test "the listing is capped at 10 and says how many more there are" {
    for i in $(seq 1 12); do
        printf '#!/bin/bash\nsource "$LIB_DIR/helper.sh"\n' > "$TMP_PROJECT/lib/c$i.sh"
        card "lib/c$i.sh" ''
    done
    run run_drift --summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"… and 2 more"* ]]
    [[ "$output" == *"divergent: 12"* ]]
}

@test "drift does not modify any card — the section is read-only" {
    card lib/consumer.sh ''
    local before after
    before=$(cd "$COMPONENTS_DIR" && md5sum *.yaml | sort)
    run run_drift --summary
    [ "$status" -eq 0 ]
    after=$(cd "$COMPONENTS_DIR" && md5sum *.yaml | sort)
    [ "$before" = "$after" ]
}
