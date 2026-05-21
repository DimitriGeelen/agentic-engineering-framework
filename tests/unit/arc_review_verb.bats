#!/usr/bin/env bats
# T-1962 — fw arc review <slug> CLI verb.
#
# Pins the contract:
#   - Resolves slug OR arc-NNN form via _arc_normalize_input (mirrors arc_close).
#   - Emits /arcs/<id>/close URL + arc summary on stdout for in-progress / draft arcs.
#   - Refuses on terminal states (closed / abandoned) with status text, no URL.
#   - Unknown arc → non-zero exit with clear message.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/project"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    export ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
    mkdir -p "$ARCS_DIR" "$PROJECT_ROOT/.context/working"

    # Three arcs: one in-progress (the happy path), one closed (refuse), one with
    # arc-NNN id to exercise the normalisation path.
    cat > "$ARCS_DIR/sample-arc.yaml" <<'YAML'
id: arc-091
slug: sample-arc
name: "Sample arc"
description: test fixture
status: in-progress
anchor_task: T-9991
created: 2026-01-01T00:00:00Z
constituent_tasks: []
YAML

    cat > "$ARCS_DIR/closed-arc.yaml" <<'YAML'
id: arc-092
slug: closed-arc
name: "Closed arc"
description: test fixture
status: closed
anchor_task: T-9992
created: 2026-01-01T00:00:00Z
closed: 2026-02-01T00:00:00Z
constituent_tasks: []
YAML

    cat > "$ARCS_DIR/abandoned-arc.yaml" <<'YAML'
id: arc-093
slug: abandoned-arc
name: "Abandoned arc"
description: test fixture
status: abandoned
anchor_task: T-9993
created: 2026-01-01T00:00:00Z
constituent_tasks: []
YAML

    # shellcheck disable=SC1091
    source "$FRAMEWORK_ROOT/lib/arc.sh"
}

# --- Happy path ---

@test "T-1962: arc_review prints URL containing /arcs/<slug>/close" {
    run arc_review "sample-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/arcs/sample-arc/close"* ]]
}

@test "T-1962: arc_review emits arc summary (status, anchor, name)" {
    run arc_review "sample-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Status: in-progress"* ]]
    [[ "$output" == *"Anchor: T-9991"* ]]
    [[ "$output" == *"Name:"* ]]
    [[ "$output" == *"Sample arc"* ]]
}

@test "T-1962: arc_review header banner identifies the verb" {
    run arc_review "sample-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Arc Close Review: sample-arc"* ]]
}

@test "T-1962: arc_review accepts arc-NNN form (mirrors close/show)" {
    run arc_review "arc-091"
    [ "$status" -eq 0 ]
    # URL still uses the canonical slug, not arc-NNN
    [[ "$output" == *"/arcs/sample-arc/close"* ]]
}

# --- Refusal paths ---

@test "T-1962: arc_review refuses closed arc with status text, no URL" {
    run arc_review "closed-arc"
    [ "$status" -ne 0 ]
    [[ "$output" == *"closed"* ]]
    # Critical: no /close URL leaks — would invite a wasted click.
    [[ "$output" != *"/arcs/closed-arc/close"* ]]
}

@test "T-1962: arc_review refuses abandoned arc with status text, no URL" {
    run arc_review "abandoned-arc"
    [ "$status" -ne 0 ]
    [[ "$output" == *"abandoned"* ]]
    [[ "$output" != *"/arcs/abandoned-arc/close"* ]]
}

@test "T-1962: arc_review unknown slug errors cleanly" {
    run arc_review "no-such-arc"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "T-1962: arc_review with no argument prints usage and exits non-zero" {
    run arc_review ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# --- Dispatch wiring ---

@test "T-1962: arc_dispatch routes 'review' to arc_review" {
    run arc_dispatch review "sample-arc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/arcs/sample-arc/close"* ]]
}

@test "T-1962: arc_help lists 'review <id>' under verbs" {
    run arc_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"review <id>"* ]]
    [[ "$output" == *"T-1962"* ]]
}
