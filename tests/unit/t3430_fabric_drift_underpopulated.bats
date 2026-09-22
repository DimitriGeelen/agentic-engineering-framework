#!/usr/bin/env bats
# T-3430: `fw fabric drift` gains the under-populated class.
#
# The class exists because the three original classes cannot see it: an
# under-populated card IS registered, its file DOES exist, and its absent edges
# cannot be stale. So the control that matters here is the negative one — a
# fixture that is clean on every other axis and still gets flagged.
#
# Every fixture is built in a tmp project (L-599): the live corpus moves under
# the test for reasons unrelated to these rules.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB_DIR="$FRAMEWORK_ROOT/agents/fabric/lib"

setup() {
    TMP_PROJECT=$(mktemp -d)
    COMPONENTS_DIR="$TMP_PROJECT/.fabric/components"
    mkdir -p "$COMPONENTS_DIR" "$TMP_PROJECT/lib"
    touch "$TMP_PROJECT/lib/a.sh" "$TMP_PROJECT/lib/b.sh" \
          "$TMP_PROJECT/lib/c.sh" "$TMP_PROJECT/lib/d.sh"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

# A card that is clean on every axis: real purpose, routed subsystem, one edge.
card_clean() {
    cat > "$COMPONENTS_DIR/lib-$1.yaml" <<YAML
id: lib/$1.sh
name: $1
location: lib/$1.sh
subsystem: framework-core
purpose: "A sentence that says what this does."
depends_on:
  - target: lib/other.sh
    type: calls
depended_by: []
YAML
}

card_flagged() {
    local slug="$1" purpose="$2" subsystem="$3" edges="$4"
    cat > "$COMPONENTS_DIR/lib-$slug.yaml" <<YAML
id: lib/$slug.sh
name: $slug
location: lib/$slug.sh
subsystem: $subsystem
purpose: "$purpose"
depends_on: $edges
depended_by: []
YAML
}

scan() {
    python3 "$LIB_DIR/underpopulated.py" "$COMPONENTS_DIR" "$@"
}

@test "T-3430 control: a fully-populated card is NOT flagged" {
    card_clean a
    run scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"##UP_TOTAL=0##"* ]]
    [[ "$output" != *"lib/a.sh"* ]]
}

@test "T-3430: a TODO purpose is flagged" {
    card_clean a
    card_flagged b "TODO: describe what this component does" framework-core \
        '[{target: lib/other.sh, type: calls}]'
    run scan
    [[ "$output" == *"lib/b.sh (TODO purpose)"* ]]
    [[ "$output" == *"##UP_TODO=1##"* ]]
    [[ "$output" == *"##UP_TOTAL=1##"* ]]
}

@test "T-3430: an unknown subsystem is flagged" {
    card_clean a
    card_flagged c "A real sentence about this file." unknown \
        '[{target: lib/other.sh, type: calls}]'
    run scan
    [[ "$output" == *"lib/c.sh (unknown subsystem)"* ]]
    [[ "$output" == *"##UP_UNKNOWN=1##"* ]]
}

@test "T-3430: zero edges is flagged" {
    card_clean a
    card_flagged d "A real sentence about this file." framework-core '[]'
    run scan
    [[ "$output" == *"lib/d.sh (no edges)"* ]]
    [[ "$output" == *"##UP_NOEDGES=1##"* ]]
}

@test "T-3430: the three sub-classes are counted separately, total is distinct cards" {
    card_flagged b "TODO: describe what this component does" unknown '[]'
    run scan
    # One card, three flags — counted once in the total, once in each sub-class.
    [[ "$output" == *"##UP_TODO=1##"* ]]
    [[ "$output" == *"##UP_UNKNOWN=1##"* ]]
    [[ "$output" == *"##UP_NOEDGES=1##"* ]]
    [[ "$output" == *"##UP_TOTAL=1##"* ]]
    [[ "$output" == *"TODO purpose, unknown subsystem, no edges"* ]]
}

@test "T-3430: only the first 10 offenders are listed, the rest are counted" {
    for i in $(seq 1 12); do
        card_flagged "x$i" "TODO: describe what this component does" framework-core \
            '[{target: lib/other.sh, type: calls}]'
    done
    run scan
    [[ "$output" == *"… and 2 more"* ]]
    [[ "$output" == *"##UP_TOTAL=12##"* ]]
}

@test "T-3430: --limit and --json are honoured" {
    card_flagged b "TODO: describe what this component does" unknown '[]'
    run scan --json --limit 1
    [ "$status" -eq 0 ]
    run python3 -c "
import json,sys
d = json.loads(sys.argv[1])
assert d['counts']['total'] == 1, d
assert d['offenders'][0]['location'] == 'lib/b.sh', d
print('ok')
" "$output"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "T-3430: an unparseable card is skipped, not fatal" {
    card_clean a
    printf 'not: [valid: yaml\n' > "$COMPONENTS_DIR/broken.yaml"
    run scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"##UP_TOTAL=0##"* ]]
}

@test "T-3430: drift reports under-populated in its summary alongside the other classes" {
    card_flagged b "TODO: describe what this component does" unknown '[]'
    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
    ensure_fabric_dirs() { :; }
    # shellcheck source=agents/fabric/lib/drift.sh
    source "$LIB_DIR/drift.sh"
    run do_drift --summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"Under-populated cards:"* ]]
    [[ "$output" == *"under-populated: 1"* ]]
    [[ "$output" == *"under-populated-todo-purpose: 1"* ]]
    [[ "$output" == *"under-populated-unknown-subsystem: 1"* ]]
    [[ "$output" == *"under-populated-no-edges: 1"* ]]
    [[ "$output" == *"fw fabric enrich --describe-only"* ]]
}

@test "T-3430: drift says (none) and reports 0 on a fully-populated corpus" {
    card_clean a
    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
    ensure_fabric_dirs() { :; }
    # shellcheck source=agents/fabric/lib/drift.sh
    source "$LIB_DIR/drift.sh"
    run do_drift --summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"under-populated: 0"* ]]
}
